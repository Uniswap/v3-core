import { ethers, waffle } from 'hardhat'
import { BigNumber, BigNumberish, constants, Contract, Wallet } from 'ethers'
import { TestERC20 } from '../typechain/TestERC20'
import { UniswapV3Factory } from '../typechain/UniswapV3Factory'
import { MockTimeUniswapV3Pair } from '../typechain/MockTimeUniswapV3Pair'
import { expect } from './shared/expect'

import { pairFixture, TEST_PAIR_START_TIME } from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'

import {
  expandTo18Decimals,
  FeeAmount,
  getPositionKey,
  getMaxTick,
  getMinTick,
  MAX_LIQUIDITY_GROSS_PER_TICK,
  encodePriceSqrt,
  TICK_SPACINGS,
  createPairFunctions,
  SwapFunction,
  MintFunction,
  InitializeFunction,
  PairFunctions,
  createMultiPairFunctions,
  MultiPairFunctions,
} from './shared/utilities'
import { TestUniswapV3Router } from '../typechain/TestUniswapV3Router'
import { SqrtTickMathTest } from '../typechain/SqrtTickMathTest'
import { SwapMathTest } from '../typechain/SwapMathTest'
import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'
import { isBytes } from 'ethers/lib/utils'

const feeAmount = FeeAmount.MEDIUM
const tickSpacing = TICK_SPACINGS[feeAmount]

const MIN_TICK = getMinTick(tickSpacing)
const MAX_TICK = getMaxTick(tickSpacing)

const createFixtureLoader = waffle.createFixtureLoader


type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('UniswapV3Pair', () => {
  let wallet: Wallet
  let other: Wallet
  let walletAddress: string
  let otherAddress: string

  let token0: TestERC20
  let token1: TestERC20
  let token2: TestERC20
  let factory: UniswapV3Factory
  let pair0: MockTimeUniswapV3Pair
  let pair1: MockTimeUniswapV3Pair

  let swapTargetCallee: TestUniswapV3Callee
  let swapTargetRouter: TestUniswapV3Router

  let pair0Functions: Contract
  let pair1Functions: Contract

  let swapToLowerPrice: SwapFunction
  let swapToHigherPrice: SwapFunction
  let swapExact0For1: SwapFunction
  let swap0ForExact1: SwapFunction
  let swapExact1For0: SwapFunction
  let swap1ForExact0: SwapFunction

  let mint: MintFunction
  let initialize: InitializeFunction

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPair: ThenArg<ReturnType<typeof pairFixture>>['createPair']

  before('get wallet and other', async () => {
    ;[wallet, other] = await waffle.provider.getWallets()
    ;[walletAddress, otherAddress] = [wallet.address, other.address]
    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy first fixture', async () => {
    ;({ token0, token1, token2, factory, createPair, swapTargetCallee, swapTargetRouter } = await loadFixture(pairFixture))

    const createPairWrapped = async (
      amount: number,
      spacing: number,
      firstToken: TestERC20,
      secondToken: TestERC20
    ): Promise<[MockTimeUniswapV3Pair, any]> => {
      const pair = await createPair(
        amount, 
        spacing, 
        firstToken, 
        secondToken
      )
      const pairFunctions = createPairFunctions({
        swapTarget: swapTargetCallee,
        token0: firstToken,
        token1: secondToken,
        pair,
      })
      return [pair, pairFunctions]
    }

    // default to the 30 bips pair
     [pair0, pair0Functions] = await createPairWrapped(feeAmount, tickSpacing, token0, token1)
    ;[pair1, pair1Functions] = await createPairWrapped(feeAmount, tickSpacing, token1, token2)
  })

  it('constructor initializes immutables', async () => {
    expect(await pair0.factory()).to.eq(factory.address)
    expect(await pair0.token0()).to.eq(token0.address)
    expect(await pair0.token1()).to.eq(token1.address)
    expect(await pair1.factory()).to.eq(factory.address)
    expect(await pair1.token0()).to.eq(token1.address)
    expect(await pair1.token1()).to.eq(token2.address)
  })

  describe('#initialize', () => {
    it('fails if already initialized', async () => {
      await pair0Functions.initialize(encodePriceSqrt(1, 1))
      await pair1Functions.initialize(encodePriceSqrt(1, 1))
      await expect(pair0Functions.initialize(encodePriceSqrt(1, 1))).to.be.revertedWith('')
      await expect(pair1Functions.initialize(encodePriceSqrt(1, 1))).to.be.revertedWith('')
    })
    it('fails if starting price is too low', async () => {
      await expect(pair0Functions.initialize(1)).to.be.revertedWith('')
      await expect(pair1Functions.initialize(1)).to.be.revertedWith('')
    })
    it('fails if starting price is too high', async () => {
      await expect(pair0Functions.initialize(BigNumber.from(2).pow(160).sub(1))).to.be.revertedWith('')
      await expect(pair1Functions.initialize(BigNumber.from(2).pow(160).sub(1))).to.be.revertedWith('')
    })
    it('fails if starting price is too low or high', async () => {
      const minTick0 = await pair0.MIN_TICK()
      const maxTick0 = await pair0.MAX_TICK()
      const minTick1 = await pair1.MIN_TICK()
      const maxTick1= await pair1.MAX_TICK()

      const sqrtTickMath = (await (await ethers.getContractFactory('SqrtTickMathTest')).deploy()) as SqrtTickMathTest
      const badMinPrice0 = (await sqrtTickMath.getSqrtRatioAtTick(minTick0))._x.sub(1)
      const badMaxPrice0 = (await sqrtTickMath.getSqrtRatioAtTick(maxTick0))._x
      const badMinPrice1 = (await sqrtTickMath.getSqrtRatioAtTick(minTick1))._x.sub(1)
      const badMaxPrice1 = (await sqrtTickMath.getSqrtRatioAtTick(maxTick1))._x

      await expect(pair0Functions.initialize(badMinPrice0)).to.be.revertedWith('MIN')
      await expect(pair0Functions.initialize(badMaxPrice0)).to.be.revertedWith('MAX')
      await expect(pair1Functions.initialize(badMinPrice1)).to.be.revertedWith('MIN')
      await expect(pair1Functions.initialize(badMaxPrice1)).to.be.revertedWith('MAX')
    })
    it('sets initial variables', async () => {
      const price = encodePriceSqrt(1, 2)
      await pair0Functions.initialize(price)
      await pair1Functions.initialize(price)
      const { sqrtPriceCurrent, blockTimestampLast } = await pair0.slot0()
      expect(sqrtPriceCurrent._x).to.eq(price)
      expect(blockTimestampLast).to.eq(TEST_PAIR_START_TIME)
      expect(await pair0.tickCurrent()).to.eq(-6932)
      expect(await pair0.slot1()).to.eq(1)
    })
    it('initializes MIN_TICK and MAX_TICK', async () => {
      const price = encodePriceSqrt(1, 2)
      await pair0Functions.initialize(price)

      {
        const { liquidityGross, secondsOutside, feeGrowthOutside0, feeGrowthOutside1 } = await pair0.tickInfos(MIN_TICK)
        expect(liquidityGross).to.eq(1)
        expect(secondsOutside).to.eq(TEST_PAIR_START_TIME)
        expect(feeGrowthOutside0._x).to.eq(0)
        expect(feeGrowthOutside1._x).to.eq(0)
      }
      {
        const { liquidityGross, secondsOutside, feeGrowthOutside0, feeGrowthOutside1 } = await pair0.tickInfos(MAX_TICK)
        expect(liquidityGross).to.eq(1)
        expect(secondsOutside).to.eq(0)
        expect(feeGrowthOutside0._x).to.eq(0)
        expect(feeGrowthOutside1._x).to.eq(0)
      }
    })
    it('creates a position for address 0 for min liquidity', async () => {
      const price = encodePriceSqrt(1, 2)
      await pair0Functions.initialize(price)
      const { liquidity } = await pair0.positions(getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK))
      expect(liquidity).to.eq(1)
    })
    it('emits a Initialized event with the input tick', async () => {
      const price = encodePriceSqrt(1, 2)
      await expect(pair0Functions.initialize(price)).to.emit(pair0, 'Initialized').withArgs(price)
    })
    it('transfers the token', async () => {
      const price = encodePriceSqrt(1, 2)
      await expect(pair0Functions.initialize(price))
        .to.emit(token0, 'Transfer')
        .withArgs(walletAddress, pair0.address, 2)
        .to.emit(token1, 'Transfer')
        .withArgs(walletAddress, pair0.address, 1)
      expect(await token0.balanceOf(pair0.address)).to.eq(2)
      expect(await token1.balanceOf(pair0.address)).to.eq(1)
    })
  })

  describe('#mint', () => {
    it('fails if not initialized', async () => {
      await expect(pair0Functions.mint(walletAddress, -tickSpacing, tickSpacing, 0)).to.be.revertedWith(
        '')
      await expect(pair1Functions.mint(walletAddress, -tickSpacing, tickSpacing, 0)).to.be.revertedWith(
        '' // 'UniswapV3Pair::mint: pair not initialized''
      )
    })
    describe('after initialization', () => {
      beforeEach('initialize the pair at price of 10:1', async () => {
        await pair0Functions.initialize(encodePriceSqrt(1, 10))
        await pair1Functions.initialize(encodePriceSqrt(1, 10))
        await pair0Functions.mint(walletAddress, MIN_TICK, MAX_TICK, 3161)
        await pair1Functions.mint(walletAddress, MIN_TICK, MAX_TICK, 3161)
        await token0.approve(pair0.address, 0)
        await token1.approve(pair0.address, 0)
        await token1.approve(pair1.address, 0)
        await token2.approve(pair1.address, 0)
      })

      describe('failure cases', () => {
        it('fails if tickLower greater than tickUpper', async () => {
          await expect(pair0Functions.mint(walletAddress, 1, 0, 1)).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: tickLower must be less than tickUpper'
          )
          await expect(pair1Functions.mint(walletAddress, 1, 0, 1)).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: tickLower must be less than tickUpper'
          )
        })
        it('fails if tickLower less than min tick', async () => {
          await expect(pair0Functions.mint(walletAddress, MIN_TICK - 1, 0, 1)).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: tickLower cannot be less than min tick'
          )
          await expect(pair1Functions.mint(walletAddress, MIN_TICK - 1, 0, 1)).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: tickLower cannot be less than min tick'
          )
        })
        it('fails if tickUpper greater than max tick', async () => {
          await expect(pair0Functions.mint(walletAddress, 0, MAX_TICK + 1, 1)).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: tickUpper cannot be greater than max tick'
          )
        it('fails if tickUpper greater than max tick', async () => {
          await expect(pair1Functions.mint(walletAddress, 0, MAX_TICK + 1, 1)).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: tickUpper cannot be greater than max tick'
          )
        })
        it('fails if amount exceeds the max', async () => {
          await expect(
            pair0Functions.mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, MAX_LIQUIDITY_GROSS_PER_TICK.add(1))
          ).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: liquidity overflow in lower tick'
          )
        it('fails if amount exceeds the max', async () => {
          await expect(
            pair1Functions.mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, MAX_LIQUIDITY_GROSS_PER_TICK.add(1))
          ).to.be.revertedWith(
            '' // 'UniswapV3Pair::_updatePosition: liquidity overflow in lower tick'
          )
        })
      })
    })
   })
 })
})



  // const initializeLiquidityAmount = expandTo18Decimals(2)

  // async function initializeAtZeroTickpair0(pair0: MockTimeUniswapV3Pair): Promise<void> {
  //   await pair0Functions.initialize(encodePriceSqrt(1, 1))
  //   const [min, max] = await Promise.all([pair0.MIN_TICK(), pair0.MAX_TICK()])
  //   await pair0Functions.mint(walletAddress, min, max, initializeLiquidityAmount.sub(1))
  // }
  
  // async function initializeAtZeroTickpair1(pair1: MockTimeUniswapV3Pair): Promise<void> {
  //   await pair1Functions.initialize(encodePriceSqrt(1, 1))
  //   const [min, max] = await Promise.all([pair1.MIN_TICK(), pair1.MAX_TICK()])
  //   await pair1Functions.mint(walletAddress, min, max, initializeLiquidityAmount.sub(1))
  // }

describe.only('multi-swaps', () => {
  for (const feeAmount of [FeeAmount.LOW, FeeAmount.MEDIUM, FeeAmount.HIGH]) {
    const tickSpacing = TICK_SPACINGS[feeAmount]
    
    describe(`fee: ${feeAmount}`, () => {

        beforeEach('initialize both pairs', async () => {
          await pair0Functions.initialize(encodePriceSqrt(1, 1))
          await pair1Functions.initialize(encodePriceSqrt(1, 1))

          await pair0Functions.mint(walletAddress, MIN_TICK, MAX_TICK, expandTo18Decimals(1), '0x')
          await pair1Functions.mint(walletAddress, MIN_TICK, MAX_TICK, expandTo18Decimals(1), '0x')

          await token0.approve(pair0.address, constants.MaxUint256)
          await token1.approve(pair0.address, constants.MaxUint256)
          await token1.approve(pair1.address, constants.MaxUint256)
          await token2.approve(pair1.address, constants.MaxUint256)

          const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })

        })

      describe('multi-swaps', () => {
        it('Check multi-hop transfer events', async () => {
          const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
          await expect(swap0ForExact2(100, walletAddress))
            .to.emit(token2, 'Transfer')
            .withArgs(pair1.address, walletAddress, 100)
            .to.emit(token1, 'Transfer')
            .withArgs(pair0.address, pair1.address, 102)
            .to.emit(token0, 'Transfer')
            .withArgs(walletAddress, pair0.address, 104)
            }) 
      
            describe('gas', () => {
              it('first swap ever', async () => {
                const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
                await snapshotGasCost(swap0ForExact2(1000, walletAddress))
              })
    
              it('first swap in block', async () => {
                const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
                await swap0ForExact2(1000, walletAddress)
                await pair0.setTime(TEST_PAIR_START_TIME + 10)
                await pair1.setTime(TEST_PAIR_START_TIME + 10)
                await snapshotGasCost(swap0ForExact2(1000, walletAddress))
              })
    
              it('second swap in block', async () => {
                const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
                await swap0ForExact2(1000, walletAddress)
                await snapshotGasCost(swap0ForExact2(1000, walletAddress))
              })
    
              // it('large swap', async () => {
              //   const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
              //   await snapshotGasCost(swap0ForExact2(expandTo18Decimals(1), walletAddress))
              // })
    
              // it('gas large swap crossing several initialized ticks', async () => {
              //   const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
              //   await pair0Functions.mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
              //   await pair0Functions.mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
              //   await pair1Functions.mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
              //   await pair1Functions.mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
              //   await snapshotGasCost(swap0ForExact2(expandTo18Decimals(1), walletAddress))
              //   expect(await pair0.tickCurrent()).to.be.lt(tickSpacing * -4)
              //   expect(await pair1.tickCurrent()).to.be.lt(tickSpacing * -4)
              // })
    
              // it('gas large swap crossing several initialized ticks after some time passes', async () => {
              //   const { swap0ForExact2 } = createMultiPairFunctions({ inputToken: token0 , swapTarget: swapTargetRouter, pair0, pair1 })
              //   await pair0Functions.mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
              //   await pair0Functions.mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
              //   await pair1Functions.mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
              //   await pair1Functions.mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
              //   await swap0ForExact2(2, walletAddress)
              //   await pair0.setTime(TEST_PAIR_START_TIME + 10)
              //   await pair1.setTime(TEST_PAIR_START_TIME + 10)
              //   await snapshotGasCost(swap0ForExact2(expandTo18Decimals(1), walletAddress))
              //   expect(await pair0.tickCurrent()).to.be.lt(tickSpacing * -4)
              //   expect(await pair1.tickCurrent()).to.be.lt(tickSpacing * -4)
              // })
            })

      })  
     })
   }
  }
 )
})


      
