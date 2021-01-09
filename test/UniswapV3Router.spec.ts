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
 // MultiSwapFunction,
  MintFunction,
  InitializeFunction,
  PairFunctions,
  createMultiPairFunctions,
} from './shared/utilities'
import { TestUniswapV3Router } from '../typechain/TestUniswapV3Router'
import { SqrtTickMathTest } from '../typechain/SqrtTickMathTest'
import { SwapMathTest } from '../typechain/SwapMathTest'
import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'

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
  //let pairAddress: string

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
  //let swapAForC: MultiSwapFunction

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
    ;({ token0, token1, token2, factory, createPair, swapTargetCallee, swapTargetRouter } = await loadFixture(
      pairFixture
    ))

    const createPairWrapped = async (
      amount: number,
      spacing: number,
      firstToken: TestERC20,
      secondToken: TestERC20
    ): Promise<[MockTimeUniswapV3Pair, any]> => {
      const pair = await createPair(amount, spacing, firstToken, secondToken)
      const pairFunctions = createPairFunctions({
        token0: firstToken,
        token1: secondToken,
        swapTarget: swapTargetCallee,
        pair,
      })
      return [pair, pairFunctions]
    }

    // default to the 30 bips pair
    ;[pair0, pair0Functions] = await createPairWrapped(feeAmount, tickSpacing, token0, token1)
    ;[pair1, pair1Functions] = await createPairWrapped(feeAmount, tickSpacing, token1, token2)
  })

  it.only('constructor initializes immutables', async () => {
    expect(await pair0.factory()).to.eq(factory.address)
    expect(await pair0.token0()).to.eq(token0.address)
    expect(await pair0.token1()).to.eq(token1.address)
    expect(await pair1.factory()).to.eq(factory.address)
    expect(await pair1.token0()).to.eq(token1.address)
    expect(await pair1.token1()).to.eq(token2.address)
  })

  it.only('blah', async () => {
    await pair0Functions.initialize(encodePriceSqrt(1, 1))
    await pair1Functions.initialize(encodePriceSqrt(1, 1))

    //await pair0Functions.token0.approve(swapTargetRouter.address, constants.MaxUint256)

    //expect('approve').to.be.calledOnContract(pair0Functions.token0);
    
    //const { swap0ForExact2 } = createMultiPairFunctions({ token0: pair0Functions.token0, swapTarget: swapTargetRouter, pair0, pair1 })

    //await pair0.token0.approve(swapTargetRouter.address, constants.MaxUint256)

   // await swap0ForExact2(10, walletAddress)



  })

  // describe('#initialize', () => {
  //   it('fails if already initialized', async () => {
  //     await initialize(encodePriceSqrt(1, 1))
  //     await expect(initialize(encodePriceSqrt(1, 1))).to.be.revertedWith('')
  //   })
  //   it('fails if starting price is too low', async () => {
  //     await expect(initialize(1)).to.be.revertedWith('')
  //   })
  //   it('fails if starting price is too high', async () => {
  //     await expect(initialize(BigNumber.from(2).pow(160).sub(1))).to.be.revertedWith('')
  //   })
  //   it('fails if starting price is too low or high', async () => {
  //     const minTick = await pair.MIN_TICK()
  //     const maxTick = await pair.MAX_TICK()

  //     const sqrtTickMath = (await (await ethers.getContractFactory('SqrtTickMathTest')).deploy()) as SqrtTickMathTest
  //     const badMinPrice = (await sqrtTickMath.getSqrtRatioAtTick(minTick))._x.sub(1)
  //     const badMaxPrice = (await sqrtTickMath.getSqrtRatioAtTick(maxTick))._x

  //     await expect(initialize(badMinPrice)).to.be.revertedWith('MIN')
  //     await expect(initialize(badMaxPrice)).to.be.revertedWith('MAX')
  //   })
  //   it('sets initial variables', async () => {
  //     const price = encodePriceSqrt(1, 2)
  //     await initialize(price)
  //     const { sqrtPriceCurrent, blockTimestampLast } = await pair.slot0()
  //     expect(sqrtPriceCurrent._x).to.eq(price)
  //     expect(blockTimestampLast).to.eq(TEST_PAIR_START_TIME)
  //     expect(await pair.tickCurrent()).to.eq(-6932)
  //     expect(await pair.slot1()).to.eq(1)
  //   })
  //   it('initializes MIN_TICK and MAX_TICK', async () => {
  //     const price = encodePriceSqrt(1, 2)
  //     await initialize(price)

  //     {
  //       const { liquidityGross, secondsOutside, feeGrowthOutside0, feeGrowthOutside1 } = await pair.tickInfos(MIN_TICK)
  //       expect(liquidityGross).to.eq(1)
  //       expect(secondsOutside).to.eq(TEST_PAIR_START_TIME)
  //       expect(feeGrowthOutside0._x).to.eq(0)
  //       expect(feeGrowthOutside1._x).to.eq(0)
  //     }
  //     {
  //       const { liquidityGross, secondsOutside, feeGrowthOutside0, feeGrowthOutside1 } = await pair.tickInfos(MAX_TICK)
  //       expect(liquidityGross).to.eq(1)
  //       expect(secondsOutside).to.eq(0)
  //       expect(feeGrowthOutside0._x).to.eq(0)
  //       expect(feeGrowthOutside1._x).to.eq(0)
  //     }
  //   })
  //   it('creates a position for address 0 for min liquidity', async () => {
  //     const price = encodePriceSqrt(1, 2)
  //     await initialize(price)
  //     const { liquidity } = await pair.positions(getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK))
  //     expect(liquidity).to.eq(1)
  //   })
  //   it('emits a Initialized event with the input tick', async () => {
  //     const price = encodePriceSqrt(1, 2)
  //     await expect(initialize(price)).to.emit(pair, 'Initialized').withArgs(price)
  //   })
  //   it('transfers the token', async () => {
  //     const price = encodePriceSqrt(1, 2)
  //     await expect(initialize(price))
  //       .to.emit(token0, 'Transfer')
  //       .withArgs(walletAddress, pair.address, 2)
  //       .to.emit(token1, 'Transfer')
  //       .withArgs(walletAddress, pair.address, 1)
  //     expect(await token0.balanceOf(pair.address)).to.eq(2)
  //     expect(await token1.balanceOf(pair.address)).to.eq(1)
  //   })
  // })

  // // the combined amount of liquidity that the pair is initialized with (including the 1 minimum liquidity that is burned)
  // const initializeLiquidityAmount = expandTo18Decimals(2)
  // async function initializeAtZeroTick(pair: MockTimeUniswapV3Pair, pair1: MockTimeUniswapV3Pair): Promise<void> {
  //   await initialize(encodePriceSqrt(1, 1))
  //   const [min, max] = await Promise.all([pair.MIN_TICK(), pair.MAX_TICK()])
  //   await mint(walletAddress, min, max, initializeLiquidityAmount.sub(1))
  // }

  // describe.only('multi-hop swaps', () => {
  //   for (const feeAmount of [FeeAmount.LOW, FeeAmount.MEDIUM, FeeAmount.HIGH]) {
  //     const tickSpacing = TICK_SPACINGS[feeAmount]

  //     describe(`fee: ${feeAmount}`, () => {
  //       beforeEach('initialize at zero tick', async () => {
  //         pair0 = await createPair(feeAmount, tickSpacing)
  //         pair1 = await createPair(feeAmount, tickSpacing)
  //         await initializeAtZeroTick(pair, pair1)
  //         //let pairs: string[] = [pair.address, pair1.address]
  //       })

  //       describe.only('Multi-hop swaps', () => {
  //         it('check for three transfer events', async () => {
  //           await expect(swapAForC(1000, walletAddress))
  //             .to.emit(swapTarget, 'SwapCallback')
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(pair1.address, walletAddress, 100)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(pair.address, pair1.address, 100)
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(walletAddress, pair.address, 100)
  //           expect(await pair.to.eq(pair))
  //         })
  //       })

  //       // uses swapAforC as representative of all 4 swap functions
  //       describe('gas', () => {
  //         it('first swap ever', async () => {
  //           await snapshotGasCost(swapAForC(1000, walletAddress))
  //         })

  //         it('first swap in block', async () => {
  //           await swapAForC(1000, walletAddress)
  //           await pair.setTime(TEST_PAIR_START_TIME + 10)
  //           await snapshotGasCost(swapAForC(1000, walletAddress))
  //         })

  //         it('second swap in block', async () => {
  //           await swapAForC(1000, walletAddress)
  //           await snapshotGasCost(swapAForC(1000, walletAddress))
  //         })

  //         it('large swap', async () => {
  //           await snapshotGasCost(swapAForC(expandTo18Decimals(1), walletAddress))
  //         })

  //         it('gas large swap crossing several initialized ticks', async () => {
  //           await mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
  //           await mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
  //           await snapshotGasCost(swapAForC(expandTo18Decimals(1), walletAddress))
  //           expect(await pair.tickCurrent()).to.be.lt(tickSpacing * -4)
  //         })

  //         it('gas large swap crossing several initialized ticks after some time passes', async () => {
  //           await mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
  //           await mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
  //           await swapAForC(2, walletAddress)
  //           await pair.setTime(TEST_PAIR_START_TIME + 10)
  //           await snapshotGasCost(swapAForC(expandTo18Decimals(1), walletAddress))
  //           expect(await pair.tickCurrent()).to.be.lt(tickSpacing * -4)
  //         })
  //       })

  //       describe('swap 1000 in', () => {
  //         const IN = 1000
  //         const OUT = {
  //           [FeeAmount.LOW]: 998,
  //           [FeeAmount.MEDIUM]: 996,
  //           [FeeAmount.HIGH]: 990,
  //         }[feeAmount]

  //         it('swapExact0For1', async () => {
  //           await expect(swapExact0For1(IN, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //           expect(await pair.tickCurrent()).to.eq(-1)
  //         })

  //         it('swap0ForExact1', async () => {
  //           await expect(swap0ForExact1(OUT, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //           expect(await pair.tickCurrent()).to.eq(-1)
  //         })

  //         it('swapExact1For0', async () => {
  //           await expect(swapExact1For0(IN, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN)
  //           expect(await pair.tickCurrent()).to.eq(0)
  //         })

  //         it('swap1ForExact0', async () => {
  //           await expect(swap1ForExact0(OUT, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN)
  //           expect(await pair.tickCurrent()).to.eq(0)
  //         })
  //       })

  //       describe('swap 1e18 in, crossing several initialized ticks', () => {
  //         const commonTickSpacing = TICK_SPACINGS[FeeAmount.HIGH] // works because this is a multiple of lower fee amounts

  //         const IN = expandTo18Decimals(1)
  //         const OUT = {
  //           [FeeAmount.LOW]: '680406940877446372',
  //           [FeeAmount.MEDIUM]: '679319045855941784',
  //           [FeeAmount.HIGH]: '676591598947405339',
  //         }[feeAmount]

  //         it('swapExact0For1', async () => {
  //           await mint(walletAddress, commonTickSpacing * -2, commonTickSpacing * -1, expandTo18Decimals(1))
  //           await mint(walletAddress, commonTickSpacing * -4, commonTickSpacing * -2, expandTo18Decimals(1))
  //           await expect(swapExact0For1(IN, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //           expect(await pair.tickCurrent()).to.be.lt(commonTickSpacing * -4)
  //         })

  //         it('swap0ForExact1', async () => {
  //           const IN_ADJUSTED = {
  //             [FeeAmount.LOW]: IN,
  //             [FeeAmount.MEDIUM]: IN.sub(1),
  //             [FeeAmount.HIGH]: IN,
  //           }[feeAmount]

  //           await mint(walletAddress, commonTickSpacing * -2, commonTickSpacing * -1, expandTo18Decimals(1))
  //           await mint(walletAddress, commonTickSpacing * -4, commonTickSpacing * -2, expandTo18Decimals(1))
  //           await expect(swap0ForExact1(OUT, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN_ADJUSTED)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //           expect(await pair.tickCurrent()).to.be.lt(commonTickSpacing * -4)
  //         })

  //         it('swapExact1For0', async () => {
  //           await mint(walletAddress, commonTickSpacing, commonTickSpacing * 2, expandTo18Decimals(1))
  //           await mint(walletAddress, commonTickSpacing * 2, commonTickSpacing * 4, expandTo18Decimals(1))
  //           await expect(swapExact1For0(IN, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN)
  //           expect(await pair.tickCurrent()).to.be.gt(commonTickSpacing * 4)
  //         })

  //         it('swap1ForExact0', async () => {
  //           const IN_ADJUSTED = {
  //             [FeeAmount.LOW]: IN,
  //             [FeeAmount.MEDIUM]: IN.sub(1),
  //             [FeeAmount.HIGH]: IN,
  //           }[feeAmount]

  //           await mint(walletAddress, commonTickSpacing, commonTickSpacing * 2, expandTo18Decimals(1))
  //           await mint(walletAddress, commonTickSpacing * 2, commonTickSpacing * 4, expandTo18Decimals(1))
  //           await expect(swap1ForExact0(OUT, walletAddress))
  //             .to.emit(token0, 'Transfer')
  //             .withArgs(pair.address, walletAddress, OUT)
  //             .to.emit(token1, 'Transfer')
  //             .withArgs(walletAddress, pair.address, IN_ADJUSTED)
  //           expect(await pair.tickCurrent()).to.be.gt(commonTickSpacing * 4)
  //         })
  //       })
  //     })
  //   }
  // })
})
