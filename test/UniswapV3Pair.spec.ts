import {ethers, waffle} from 'hardhat'
import {BigNumber, BigNumberish, constants, Signer} from 'ethers'
import {TestERC20} from '../typechain/TestERC20'
import {UniswapV3Factory} from '../typechain/UniswapV3Factory'
import {MockTimeUniswapV3Pair} from '../typechain/MockTimeUniswapV3Pair'
import {expect} from './shared/expect'

import {pairFixture, TEST_PAIR_START_TIME} from './shared/fixtures'
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
} from './shared/utilities'
import {TestUniswapV3Callee} from '../typechain/TestUniswapV3Callee'
import {SqrtTickMathTest} from '../typechain/SqrtTickMathTest'
import {SwapMathTest} from '../typechain/SwapMathTest'

const feeAmount = FeeAmount.MEDIUM
const tickSpacing = TICK_SPACINGS[feeAmount]

const MIN_TICK = getMinTick(tickSpacing)
const MAX_TICK = getMaxTick(tickSpacing)

const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('UniswapV3Pair', () => {
  let wallet: Signer
  let other: Signer
  let walletAddress: string
  let otherAddress: string

  let token0: TestERC20
  let token1: TestERC20
  let token2: TestERC20
  let factory: UniswapV3Factory
  let pair: MockTimeUniswapV3Pair

  let swapTarget: TestUniswapV3Callee

  let swapExact0For1: SwapFunction
  let swap0ForExact1: SwapFunction
  let swapExact1For0: SwapFunction
  let swap1ForExact0: SwapFunction
  let mint: MintFunction
  let initialize: InitializeFunction

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPair: ThenArg<ReturnType<typeof pairFixture>>['createPair']

  before('get wallet and other', async () => {
    ;[wallet, other] = await ethers.getSigners()
    ;[walletAddress, otherAddress] = await Promise.all([wallet.getAddress(), other.getAddress()])
    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy fixture', async () => {
    ;({token0, token1, token2, factory, createPair, swapTarget} = await loadFixture(pairFixture))

    const oldCreatePair = createPair
    createPair = async (amount, spacing) => {
      const pair = await oldCreatePair(amount, spacing)
      ;({swapExact0For1, swap0ForExact1, swapExact1For0, swap1ForExact0, mint, initialize} = createPairFunctions({
        token0,
        token1,
        swapTarget,
        pair,
      }))
      return pair
    }

    // default to the 30 bips pair
    pair = await createPair(feeAmount, tickSpacing)
  })

  it('constructor initializes immutables', async () => {
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(token0.address)
    expect(await pair.token1()).to.eq(token1.address)
  })

  describe('#initialize', () => {
    it('fails if already initialized', async () => {
      await initialize(encodePriceSqrt(1, 1))
      await expect(initialize(encodePriceSqrt(1, 1))).to.be.revertedWith('')
    })
    it('fails if starting price is too low', async () => {
      await expect(initialize(1)).to.be.revertedWith('')
    })
    it('fails if starting price is too high', async () => {
      await expect(initialize(BigNumber.from(2).pow(160).sub(1))).to.be.revertedWith('')
    })
    it('sets initial variables', async () => {
      const price = encodePriceSqrt(1, 2)
      await initialize(price)
      expect(await pair.sqrtPriceCurrent()).to.eq(price)
      expect(await pair.blockTimestampLast()).to.eq(TEST_PAIR_START_TIME)
      expect(await pair.tickCurrent()).to.eq(-6932)
      expect(await pair.liquidityCurrent()).to.eq(1)
    })
    it('initializes MIN_TICK and MAX_TICK', async () => {
      const price = encodePriceSqrt(1, 2)
      await initialize(price)

      {
        const {liquidityGross, secondsOutside, feeGrowthOutside0, feeGrowthOutside1} = await pair.tickInfos(MIN_TICK)
        expect(liquidityGross).to.eq(1)
        expect(secondsOutside).to.eq(TEST_PAIR_START_TIME)
        expect(feeGrowthOutside0._x).to.eq(0)
        expect(feeGrowthOutside1._x).to.eq(0)
      }
      {
        const {liquidityGross, secondsOutside, feeGrowthOutside0, feeGrowthOutside1} = await pair.tickInfos(MAX_TICK)
        expect(liquidityGross).to.eq(1)
        expect(secondsOutside).to.eq(0)
        expect(feeGrowthOutside0._x).to.eq(0)
        expect(feeGrowthOutside1._x).to.eq(0)
      }
    })
    it('creates a position for address 0 for min liquidity', async () => {
      const price = encodePriceSqrt(1, 2)
      await initialize(price)
      const {liquidity} = await pair.positions(getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK))
      expect(liquidity).to.eq(1)
    })
    it('emits a Initialized event with the input tick', async () => {
      const price = encodePriceSqrt(1, 2)
      await expect(initialize(price)).to.emit(pair, 'Initialized').withArgs(price)
    })
    it('transfers the token', async () => {
      const price = encodePriceSqrt(1, 2)
      await expect(initialize(price))
        .to.emit(token0, 'Transfer')
        .withArgs(walletAddress, pair.address, 2)
        .to.emit(token1, 'Transfer')
        .withArgs(walletAddress, pair.address, 1)
      expect(await token0.balanceOf(pair.address)).to.eq(2)
      expect(await token1.balanceOf(pair.address)).to.eq(1)
    })
  })

  describe('#mint', () => {
    it('fails if not initialized', async () => {
      await expect(mint(walletAddress, -tickSpacing, tickSpacing, 0)).to.be.revertedWith(
        'UniswapV3Pair::mint: pair not initialized'
      )
    })
    describe('after initialization', () => {
      beforeEach('initialize the pair at price of 10:1', async () => {
        await initialize(encodePriceSqrt(1, 10))
        await mint(walletAddress, MIN_TICK, MAX_TICK, 3161)
        await token0.approve(pair.address, 0)
        await token1.approve(pair.address, 0)
      })

      describe('failure cases', () => {
        it('fails if tickLower greater than tickUpper', async () => {
          await expect(mint(walletAddress, 1, 0, 1)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: tickLower must be less than tickUpper'
          )
        })
        it('fails if tickLower less than min tick', async () => {
          await expect(mint(walletAddress, MIN_TICK - 1, 0, 1)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: tickLower cannot be less than min tick'
          )
        })
        it('fails if tickUpper greater than max tick', async () => {
          await expect(mint(walletAddress, 0, MAX_TICK + 1, 1)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: tickUpper cannot be greater than max tick'
          )
        })
        it('fails if called with 0 amount', async () => {
          await expect(mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 0)).to.be.revertedWith(
            'UniswapV3Pair::mint: amount must be greater than 0'
          )
        })
        it('fails if amount exceeds the max', async () => {
          await expect(
            mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, MAX_LIQUIDITY_GROSS_PER_TICK.add(1))
          ).to.be.revertedWith('UniswapV3Pair::_updatePosition: liquidity overflow in lower tick')
        })
      })

      describe('success cases', () => {
        it('initial prices', async () => {
          expect(await token0.balanceOf(pair.address)).to.eq(10000)
          expect(await token1.balanceOf(pair.address)).to.eq(1001)
        })

        describe('below current price', () => {
          it('transfers token0 only', async () => {
            await expect(mint(walletAddress, -22980, 0, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 21549)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 21549)
            expect(await token1.balanceOf(pair.address)).to.eq(1001)
          })

          it('works for max tick', async () => {
            await expect(mint(walletAddress, -22980, MAX_TICK, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 31549)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 31549)
            expect(await token1.balanceOf(pair.address)).to.eq(1001)
          })

          it('removing works', async () => {
            await mint(walletAddress, -240, 0, 10000)
            await pair.burn(walletAddress, -240, 0, 10000)
            expect(await token0.balanceOf(pair.address)).to.eq(10001)
            expect(await token1.balanceOf(pair.address)).to.eq(1001)
          })

          it('adds liquidity to liquidityGross', async () => {
            await mint(walletAddress, -240, 0, 100)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(100)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(100)
            expect((await pair.tickInfos(tickSpacing)).liquidityGross).to.eq(0)
            expect((await pair.tickInfos(tickSpacing * 2)).liquidityGross).to.eq(0)
            await mint(walletAddress, -240, tickSpacing, 150)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(250)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(100)
            expect((await pair.tickInfos(tickSpacing)).liquidityGross).to.eq(150)
            expect((await pair.tickInfos(tickSpacing * 2)).liquidityGross).to.eq(0)
            await mint(walletAddress, 0, tickSpacing * 2, 60)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(250)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(160)
            expect((await pair.tickInfos(tickSpacing)).liquidityGross).to.eq(150)
            expect((await pair.tickInfos(tickSpacing * 2)).liquidityGross).to.eq(60)
          })

          it('removes liquidity from liquidityGross', async () => {
            await mint(walletAddress, -240, 0, 100)
            await mint(walletAddress, -240, 0, 40)
            await pair.burn(walletAddress, -240, 0, 90)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(50)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(50)
          })

          it('clears tick lower if last position is removed', async () => {
            await mint(walletAddress, -240, 0, 100)
            await pair.burn(walletAddress, -240, 0, 100)
            const {liquidityGross, feeGrowthOutside0, feeGrowthOutside1, secondsOutside} = await pair.tickInfos(-240)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0._x).to.eq(0)
            expect(feeGrowthOutside1._x).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })

          it('clears tick upper if last position is removed', async () => {
            await mint(walletAddress, -240, 0, 100)
            await pair.burn(walletAddress, -240, 0, 100)
            const {liquidityGross, feeGrowthOutside0, feeGrowthOutside1, secondsOutside} = await pair.tickInfos(0)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0._x).to.eq(0)
            expect(feeGrowthOutside1._x).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })
          it('only clears the tick that is not used at all', async () => {
            await mint(walletAddress, -240, 0, 100)
            await mint(walletAddress, -tickSpacing, 0, 250)
            await pair.burn(walletAddress, -240, 0, 100)

            let {liquidityGross, feeGrowthOutside0, feeGrowthOutside1, secondsOutside} = await pair.tickInfos(-240)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0._x).to.eq(0)
            expect(feeGrowthOutside1._x).to.eq(0)
            expect(secondsOutside).to.eq(0)
            ;({liquidityGross, feeGrowthOutside0, feeGrowthOutside1, secondsOutside} = await pair.tickInfos(
              -tickSpacing
            ))
            expect(liquidityGross).to.eq(250)
            expect(feeGrowthOutside0._x).to.eq(0)
            expect(feeGrowthOutside1._x).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })

          it('gas', async () => {
            await snapshotGasCost(mint(walletAddress, -240, 0, 10000))
          })
        })

        describe('including current price', () => {
          it('price within range: transfers current price of both tokens', async () => {
            await expect(mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 317)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 32)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 317)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 32)
          })

          it('initializes lower tick', async () => {
            await mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            const {liquidityGross, secondsOutside} = await pair.tickInfos(MIN_TICK + tickSpacing)
            expect(liquidityGross).to.eq(100)
            expect(secondsOutside).to.eq(TEST_PAIR_START_TIME)
          })

          it('initializes upper tick', async () => {
            await mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            const {liquidityGross, secondsOutside} = await pair.tickInfos(MAX_TICK - tickSpacing)
            expect(liquidityGross).to.eq(100)
            expect(secondsOutside).to.eq(0)
          })

          it('works for min/max tick', async () => {
            await expect(mint(walletAddress, MIN_TICK, MAX_TICK, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 31623)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 3163)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 31623)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 3163)
          })

          it('removing works', async () => {
            await mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            await pair.burn(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            expect(await token0.balanceOf(pair.address)).to.eq(10001)
            expect(await token1.balanceOf(pair.address)).to.eq(1002)
          })

          it('gas', async () => {
            await snapshotGasCost(mint(walletAddress, MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100))
          })
        })

        describe('above current price', () => {
          it('transfers token1 only', async () => {
            await expect(mint(walletAddress, -46080, -23040, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 2162)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 2162)
          })

          it('works for min tick', async () => {
            await expect(mint(walletAddress, MIN_TICK, -23040, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 3161)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 3161)
          })

          it('removing works', async () => {
            await mint(walletAddress, -46080, -46020, 10000)
            await pair.burn(walletAddress, -46080, -46020, 10000)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(1002)
          })

          it('gas', async () => {
            await snapshotGasCost(await mint(walletAddress, -46080, -46020, 10000))
          })
        })
      })
    })
  })

  // the combined amount of liquidity that the pair is initialized with (including the 1 minimum liquidity that is burned)
  const initializeLiquidityAmount = expandTo18Decimals(2)
  async function initializeAtZeroTick(pair: MockTimeUniswapV3Pair): Promise<void> {
    await initialize(encodePriceSqrt(1, 1))
    const [min, max] = await Promise.all([pair.MIN_TICK(), pair.MAX_TICK()])
    await mint(walletAddress, min, max, initializeLiquidityAmount.sub(1))
  }

  describe('#getCumulatives', () => {
    it('reverts before initialization', async () => {
      await expect(pair.getCumulatives()).to.be.revertedWith('UniswapV3Pair::getCumulatives: pair not initialized')
    })

    describe('after initialization', () => {
      beforeEach(() => initializeAtZeroTick(pair))

      it('blockTimestamp is always current timestamp', async () => {
        let {blockTimestamp} = await pair.getCumulatives()
        expect(blockTimestamp).to.eq(TEST_PAIR_START_TIME)
        await pair.setTime(TEST_PAIR_START_TIME + 10)
        ;({blockTimestamp} = await pair.getCumulatives())
        expect(blockTimestamp).to.eq(TEST_PAIR_START_TIME + 10)
      })

      // zero tick
      it('tick accumulator increases by tick over time', async () => {
        let {tickCumulative} = await pair.getCumulatives()
        expect(tickCumulative).to.eq(0)
        await pair.setTime(TEST_PAIR_START_TIME + 10)
        ;({tickCumulative} = await pair.getCumulatives())
        expect(tickCumulative).to.eq(0)
      })

      it('tick accumulator after swap', async () => {
        // moves to tick -1
        await swapExact0For1(1000, walletAddress)
        await pair.setTime(TEST_PAIR_START_TIME + 4)
        let {tickCumulative} = await pair.getCumulatives()
        expect(tickCumulative).to.eq(-4)
      })

      it('tick accumulator after two swaps', async () => {
        await swapExact0For1(expandTo18Decimals(1).div(2), walletAddress)
        expect(await pair.tickCurrent()).to.eq(-4452)
        await pair.setTime(TEST_PAIR_START_TIME + 4)
        await swapExact1For0(expandTo18Decimals(1).div(4), walletAddress)
        expect(await pair.tickCurrent()).to.eq(-1558)
        await pair.setTime(TEST_PAIR_START_TIME + 10)
        let {tickCumulative} = await pair.getCumulatives()
        // -4452*4 + -1558*6
        expect(tickCumulative).to.eq(-27156)
      })
    })
  })

  describe('swaps', () => {
    for (const feeAmount of [FeeAmount.LOW, FeeAmount.MEDIUM, FeeAmount.HIGH]) {
      const tickSpacing = TICK_SPACINGS[feeAmount]

      describe(`fee: ${feeAmount}`, () => {
        beforeEach('initialize at zero tick', async () => {
          pair = await createPair(feeAmount, tickSpacing)
          await initializeAtZeroTick(pair)
        })

        // uses swapExact0For1 as representative of all 4 swap functions
        describe('gas', () => {
          it('first swap ever', async () => {
            await snapshotGasCost(swapExact0For1(1000, walletAddress))
          })

          it('first swap in block', async () => {
            await swapExact0For1(1000, walletAddress)
            await pair.setTime(TEST_PAIR_START_TIME + 10)
            await snapshotGasCost(swapExact0For1(1000, walletAddress))
          })

          it('second swap in block', async () => {
            await swapExact0For1(1000, walletAddress)
            await snapshotGasCost(swapExact0For1(1000, walletAddress))
          })

          it('large swap', async () => {
            await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), walletAddress))
          })

          it('gas large swap crossing several initialized ticks', async () => {
            await mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
            await mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
            await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), walletAddress))
            expect(await pair.tickCurrent()).to.be.lt(tickSpacing * -4)
          })

          it('gas large swap crossing several initialized ticks after some time passes', async () => {
            await mint(walletAddress, tickSpacing * -3, tickSpacing * -2, expandTo18Decimals(1))
            await mint(walletAddress, tickSpacing * -4, tickSpacing * -3, expandTo18Decimals(1))
            await swapExact0For1(2, walletAddress)
            await pair.setTime(TEST_PAIR_START_TIME + 10)
            await snapshotGasCost(swapExact0For1(expandTo18Decimals(1), walletAddress))
            expect(await pair.tickCurrent()).to.be.lt(tickSpacing * -4)
          })
        })

        describe('swap 1000 in', () => {
          const IN = 1000
          const OUT = {
            [FeeAmount.LOW]: 998,
            [FeeAmount.MEDIUM]: 996,
            [FeeAmount.HIGH]: 990,
          }[feeAmount]

          it('swapExact0For1', async () => {
            await expect(swapExact0For1(IN, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, IN)
              .to.emit(token1, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
            expect(await pair.tickCurrent()).to.eq(-1)
          })

          it('swap0ForExact1', async () => {
            await expect(swap0ForExact1(OUT, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, IN)
              .to.emit(token1, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
            expect(await pair.tickCurrent()).to.eq(-1)
          })

          it('swapExact1For0', async () => {
            await expect(swapExact1For0(IN, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, IN)
            expect(await pair.tickCurrent()).to.eq(0)
          })

          it('swap1ForExact0', async () => {
            await expect(swap1ForExact0(OUT, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, IN)
            expect(await pair.tickCurrent()).to.eq(0)
          })
        })

        describe('swap 1e18 in, crossing several initialized ticks', () => {
          const commonTickSpacing = TICK_SPACINGS[FeeAmount.HIGH] // works because this is a multiple of lower fee amounts

          const IN = expandTo18Decimals(1)
          const OUT = {
            [FeeAmount.LOW]: '680406940877446372',
            [FeeAmount.MEDIUM]: '679319045855941784',
            [FeeAmount.HIGH]: '676591598947405339',
          }[feeAmount]

          it('swapExact0For1', async () => {
            await mint(walletAddress, commonTickSpacing * -2, commonTickSpacing * -1, expandTo18Decimals(1))
            await mint(walletAddress, commonTickSpacing * -4, commonTickSpacing * -2, expandTo18Decimals(1))
            await expect(swapExact0For1(IN, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, IN)
              .to.emit(token1, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
            expect(await pair.tickCurrent()).to.be.lt(commonTickSpacing * -4)
          })

          it('swap0ForExact1', async () => {
            const IN_ADJUSTED = {
              [FeeAmount.LOW]: IN,
              [FeeAmount.MEDIUM]: IN.sub(1),
              [FeeAmount.HIGH]: IN,
            }[feeAmount]

            await mint(walletAddress, commonTickSpacing * -2, commonTickSpacing * -1, expandTo18Decimals(1))
            await mint(walletAddress, commonTickSpacing * -4, commonTickSpacing * -2, expandTo18Decimals(1))
            await expect(swap0ForExact1(OUT, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, IN_ADJUSTED)
              .to.emit(token1, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
            expect(await pair.tickCurrent()).to.be.lt(commonTickSpacing * -4)
          })

          it('swapExact1For0', async () => {
            await mint(walletAddress, commonTickSpacing, commonTickSpacing * 2, expandTo18Decimals(1))
            await mint(walletAddress, commonTickSpacing * 2, commonTickSpacing * 4, expandTo18Decimals(1))
            await expect(swapExact1For0(IN, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, IN)
            expect(await pair.tickCurrent()).to.be.gt(commonTickSpacing * 4)
          })

          it('swap1ForExact0', async () => {
            const IN_ADJUSTED = {
              [FeeAmount.LOW]: IN,
              [FeeAmount.MEDIUM]: IN.sub(1),
              [FeeAmount.HIGH]: IN,
            }[feeAmount]

            await mint(walletAddress, commonTickSpacing, commonTickSpacing * 2, expandTo18Decimals(1))
            await mint(walletAddress, commonTickSpacing * 2, commonTickSpacing * 4, expandTo18Decimals(1))
            await expect(swap1ForExact0(OUT, walletAddress))
              .to.emit(token0, 'Transfer')
              .withArgs(pair.address, walletAddress, OUT)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, IN_ADJUSTED)
            expect(await pair.tickCurrent()).to.be.gt(commonTickSpacing * 4)
          })
        })
      })
    }
  })

  describe('miscellaneous setPosition tests', () => {
    beforeEach('initialize at zero tick', async () => {
      pair = await createPair(FeeAmount.LOW, TICK_SPACINGS[FeeAmount.LOW])
      await initializeAtZeroTick(pair)
    })

    it('mint to the right of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = tickSpacing
      const upperTick = tickSpacing * 2

      const k = await pair.liquidityCurrent()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await mint(walletAddress, lowerTick, upperTick, liquidityDelta)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(3)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(0)
    })

    it('mint to the left of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -tickSpacing * 2
      const upperTick = -tickSpacing

      const k = await pair.liquidityCurrent()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await mint(walletAddress, lowerTick, upperTick, liquidityDelta)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(0)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(3)
    })

    it('mint within the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing

      const k = await pair.liquidityCurrent()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await mint(walletAddress, lowerTick, upperTick, liquidityDelta)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(3)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(3)
    })

    it('cannot remove more than the entire position', async () => {
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing
      await mint(walletAddress, lowerTick, upperTick, expandTo18Decimals(1000))
      await expect(pair.burn(walletAddress, lowerTick, upperTick, expandTo18Decimals(1001))).to.be.revertedWith(
        'UniswapV3Pair::_updatePosition: cannot remove more than current position liquidity'
      )
    })

    it('collect fees within the current price after swap', async () => {
      let liquidityDelta = expandTo18Decimals(100)
      const lowerTick = -tickSpacing * 100
      const upperTick = tickSpacing * 100

      await mint(walletAddress, lowerTick, upperTick, liquidityDelta)

      const k = await pair.liquidityCurrent()

      const amount0In = expandTo18Decimals(1)
      await swapExact0For1(amount0In, walletAddress)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter, 'k increases').to.be.gte(k)

      const token0BalanceBeforePair = await token0.balanceOf(pair.address)
      const token1BalanceBeforePair = await token1.balanceOf(pair.address)
      const token0BalanceBeforeWallet = await token0.balanceOf(walletAddress)
      const token1BalanceBeforeWallet = await token1.balanceOf(walletAddress)

      await pair.collectFees(lowerTick, upperTick, walletAddress, constants.MaxUint256, constants.MaxUint256)

      const {amount0: fees0, amount1: fees1} = await pair.callStatic.collectFees(
        lowerTick,
        upperTick,
        walletAddress,
        constants.MaxUint256,
        constants.MaxUint256
      )
      expect(fees0).to.be.eq(0)
      expect(fees1).to.be.eq(0)

      const token0BalanceAfterWallet = await token0.balanceOf(walletAddress)
      const token1BalanceAfterWallet = await token1.balanceOf(walletAddress)
      const token0BalanceAfterPair = await token0.balanceOf(pair.address)
      const token1BalanceAfterPair = await token1.balanceOf(pair.address)

      expect(token0BalanceAfterWallet).to.be.gt(token0BalanceBeforeWallet)
      expect(token1BalanceAfterWallet).to.be.eq(token1BalanceBeforeWallet)

      expect(token0BalanceAfterPair).to.be.lt(token0BalanceBeforePair)
      expect(token1BalanceAfterPair).to.be.eq(token1BalanceBeforePair)
    })
  })

  describe('post-initialize at medium fee', () => {
    // beforeEach('initialize the pair', async () => {
    //   await initializeAtZeroTick(pair)
    // })

    describe('k (implicit)', () => {
      it('returns 0 before initialization', async () => {
        expect(await pair.liquidityCurrent()).to.eq(0)
      })
      describe('post initialized', () => {
        beforeEach(() => initializeAtZeroTick(pair))

        it('returns initial liquidity', async () => {
          expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(2))
        })
        it('returns in supply in range', async () => {
          await mint(walletAddress, -tickSpacing, tickSpacing, expandTo18Decimals(3))
          expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(5))
        })
        it('excludes supply at tick above current tick', async () => {
          await mint(walletAddress, tickSpacing, tickSpacing * 2, expandTo18Decimals(3))
          expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(2))
        })
        it('excludes supply at tick below current tick', async () => {
          await mint(walletAddress, -tickSpacing * 2, -tickSpacing, expandTo18Decimals(3))
          expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(2))
        })
        it('updates correctly when exiting range', async () => {
          const kBefore = await pair.liquidityCurrent()
          expect(kBefore).to.be.eq(expandTo18Decimals(2))

          // add liquidity at and above current tick
          const liquidityDelta = expandTo18Decimals(1)
          const lowerTick = 0
          const upperTick = tickSpacing
          await mint(walletAddress, lowerTick, upperTick, liquidityDelta)

          // ensure virtual supply has increased appropriately
          const kAfter = await pair.liquidityCurrent()
          expect(kAfter).to.be.gt(kBefore)
          expect(kAfter).to.be.eq(expandTo18Decimals(3))

          // swap toward the left (just enough for the tick transition function to trigger)
          // TODO if the input amount is 1 here, the tick transition fires incorrectly!
          // should throw an error or something once the TODOs in pair are fixed
          await swapExact0For1(2, walletAddress)
          const tick = await pair.tickCurrent()
          expect(tick).to.be.eq(-1)

          const kAfterSwap = await pair.liquidityCurrent()
          expect(kAfterSwap).to.be.lt(kAfter)
          // TODO not sure this is right
          expect(kAfterSwap).to.be.eq(expandTo18Decimals(2))
        })
        it('updates correctly when entering range', async () => {
          const kBefore = await pair.liquidityCurrent()
          expect(kBefore).to.be.eq(expandTo18Decimals(2))

          // add liquidity below the current tick
          const liquidityDelta = expandTo18Decimals(1)
          const lowerTick = -tickSpacing
          const upperTick = 0
          await mint(walletAddress, lowerTick, upperTick, liquidityDelta)

          // ensure virtual supply hasn't changed
          const kAfter = await pair.liquidityCurrent()
          expect(kAfter).to.be.eq(kBefore)

          // swap toward the left (just enough for the tick transition function to trigger)
          // TODO if the input amount is 1 here, the tick transition fires incorrectly!
          // should throw an error or something once the TODOs in pair are fixed
          await swapExact0For1(2, walletAddress)
          const tick = await pair.tickCurrent()
          expect(tick).to.be.eq(-1)

          const kAfterSwap = await pair.liquidityCurrent()
          expect(kAfterSwap).to.be.gt(kAfter)
          // TODO not sure this is right
          expect(kAfterSwap).to.be.eq(expandTo18Decimals(3))
        })
      })
    })
  })

  describe('limit orders', () => {
    beforeEach('initialize at tick 0', () => initializeAtZeroTick(pair))

    it('selling 1 for 0 at tick 0 thru 1', async () => {
      await expect(mint(walletAddress, 0, 120, expandTo18Decimals(1)))
        .to.emit(token0, 'Transfer')
        .withArgs(walletAddress, pair.address, '5981737760509663')
      // somebody takes the limit order
      await swapExact1For0(expandTo18Decimals(2), otherAddress)
      await expect(pair.burn(walletAddress, 0, 120, expandTo18Decimals(1)))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '6017734268818165')
    })
    it('selling 0 for 1 at tick 0 thru -1', async () => {
      await expect(mint(walletAddress, -120, 0, expandTo18Decimals(1)))
        .to.emit(token1, 'Transfer')
        .withArgs(walletAddress, pair.address, '5981737760509663')
      // somebody takes the limit order
      await swapExact0For1(expandTo18Decimals(2), otherAddress)
      await expect(pair.burn(walletAddress, -120, 0, expandTo18Decimals(1)))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '6017734268818165')
    })

    describe('fee is on', () => {
      beforeEach(() => pair.setFeeTo(walletAddress))
      it('selling 1 for 0 at tick 0 thru 1', async () => {
        await expect(mint(walletAddress, 0, 120, expandTo18Decimals(1)))
          .to.emit(token0, 'Transfer')
          .withArgs(walletAddress, pair.address, '5981737760509663')
        // somebody takes the limit order
        await swapExact1For0(expandTo18Decimals(2), otherAddress)
        await expect(pair.burn(walletAddress, 0, 120, expandTo18Decimals(1)))
          .to.emit(token1, 'Transfer')
          .withArgs(pair.address, walletAddress, '6017734268818165')
      })
      it('selling 0 for 1 at tick 0 thru -1', async () => {
        await expect(mint(walletAddress, -120, 0, expandTo18Decimals(1)))
          .to.emit(token1, 'Transfer')
          .withArgs(walletAddress, pair.address, '5981737760509663')
        // somebody takes the limit order
        await swapExact0For1(expandTo18Decimals(2), otherAddress)
        await expect(pair.burn(walletAddress, -120, 0, expandTo18Decimals(1)))
          .to.emit(token0, 'Transfer')
          .withArgs(pair.address, walletAddress, '6017734268818165')
      })
    })
  })

  describe('#feeTo', () => {
    const liquidityAmount = expandTo18Decimals(1000)

    beforeEach(async () => {
      pair = await createPair(FeeAmount.LOW, TICK_SPACINGS[FeeAmount.LOW])
      await initialize(encodePriceSqrt(1, 1))
      await mint(walletAddress, MIN_TICK, MAX_TICK, liquidityAmount)
    })

    it('is initially set to address 0', async () => {
      expect(await pair.feeTo()).to.eq(constants.AddressZero)
    })

    it('can be changed by the owner', async () => {
      await pair.setFeeTo(otherAddress)
      expect(await pair.feeTo()).to.eq(otherAddress)
    })

    it('cannot be changed by addresses that are not owner', async () => {
      await expect(pair.connect(other).setFeeTo(otherAddress)).to.be.revertedWith(
        'UniswapV3Pair::setFeeTo: caller not owner'
      )
    })

    async function swapAndGetFeesOwed(swapAmount: BigNumberish = expandTo18Decimals(1), zeroForOne: boolean = true) {
      await (zeroForOne ? swapExact0For1(swapAmount, walletAddress) : swapExact1For0(swapAmount, walletAddress))

      const {amount0: fees0, amount1: fees1} = await pair.callStatic.collectFees(
        MIN_TICK,
        MAX_TICK,
        walletAddress,
        constants.MaxUint256,
        constants.MaxUint256
      )

      expect(fees0, 'fees owed in token0 are greater than 0').to.be.gte(0)
      expect(fees1, 'fees owed in token1 are greater than 0').to.be.gte(0)

      return {token0Fees: fees0, token1Fees: fees1}
    }

    it('position owner gets full fees when protocol fee is off', async () => {
      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      // 6 bips * 1e18
      expect(token0Fees).to.eq('599999999999999')
      expect(token1Fees).to.eq(0)
    })

    it('position owner gets partial fees when protocol fee is on', async () => {
      await pair.setFeeTo(otherAddress)

      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      expect(token0Fees).to.be.eq('500000000000000')
      expect(token1Fees).to.be.eq(0)
    })

    describe('#collect', () => {
      it('returns 0 if no fees', async () => {
        await pair.setFeeTo(otherAddress)
        const {amount0, amount1} = await pair.callStatic.collect(constants.MaxUint256, constants.MaxUint256)
        expect(amount0).to.be.eq(0)
        expect(amount1).to.be.eq(0)
      })

      it('can collect fees', async () => {
        await pair.setFeeTo(otherAddress)

        await swapAndGetFeesOwed()
        // collect fees to trigger collection of the protocol fee
        await pair.collectFees(MIN_TICK, MAX_TICK, walletAddress, constants.MaxUint256, constants.MaxUint256)

        await expect(pair.collect(constants.MaxUint256, constants.MaxUint256))
          .to.emit(token0, 'Transfer')
          .withArgs(pair.address, otherAddress, '99999999999999')
      })
    })

    it('fees collected by lp after two swaps should be double one swap', async () => {
      await swapAndGetFeesOwed()
      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      // 6 bips * 2e18
      expect(token0Fees).to.eq('1199999999999999')
      expect(token1Fees).to.eq(0)
    })

    it('fees collected after two swaps with fee turned on in middle are fees from both swaps (confiscatory)', async () => {
      await swapAndGetFeesOwed()

      await pair.setFeeTo(otherAddress)

      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      expect(token0Fees).to.eq('1000000000000000')
      expect(token1Fees).to.eq(0)
    })

    it('fees collected by lp after two swaps with intermediate withdrawal', async () => {
      await pair.setFeeTo(otherAddress)

      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      expect(token0Fees).to.eq('500000000000000')
      expect(token1Fees).to.eq(0)

      // collect the fees
      await pair.collectFees(MIN_TICK, MAX_TICK, walletAddress, constants.MaxUint256, constants.MaxUint256)

      const {token0Fees: token0FeesNext, token1Fees: token1FeesNext} = await swapAndGetFeesOwed()

      expect(token0FeesNext).to.eq('500000000000000')
      expect(token1FeesNext).to.eq(0)

      // the fee to fees do not account for uncollected fees yet
      expect(await pair.feeToFees0()).to.be.eq('99999999999999')
      expect(await pair.feeToFees1()).to.be.eq(0)

      await pair.collectFees(MIN_TICK, MAX_TICK, walletAddress, constants.MaxUint256, constants.MaxUint256)
      expect(await pair.feeToFees0()).to.be.eq('199999999999998')
      expect(await pair.feeToFees1()).to.be.eq(0)
    })
  })

  describe('#recover', () => {
    beforeEach('initialize the pair', () => initializeAtZeroTick(pair))

    beforeEach('send some token2 to the pair', async () => {
      await token2.transfer(pair.address, 10)
    })

    it('is only callable by owner', async () => {
      await expect(pair.connect(other).recover(token2.address, otherAddress, 10)).to.be.revertedWith(
        'UniswapV3Pair::recover: caller not owner'
      )
    })

    it('does not allow transferring a token from the pair', async () => {
      await expect(pair.recover(token0.address, otherAddress, 10)).to.be.revertedWith(
        'UniswapV3Pair::recover: cannot recover token0 or token1'
      )
    })

    it('allows recovery from the pair', async () => {
      await expect(pair.recover(token2.address, otherAddress, 10))
        .to.emit(token2, 'Transfer')
        .withArgs(pair.address, otherAddress, 10)
    })
  })

  describe('#tickSpacing', () => {
    it('default tickSpacing is correct', async () => {
      expect(await pair.MIN_TICK()).to.eq(MIN_TICK)
      expect(await pair.MAX_TICK()).to.eq(MAX_TICK)
    })

    describe('tickSpacing = 12', () => {
      beforeEach('deploy pair', async () => {
        pair = await createPair(FeeAmount.MEDIUM, 12)
      })
      it('min and max tick are multiples of 12', async () => {
        expect(await pair.MIN_TICK()).to.eq(-887268)
        expect(await pair.MAX_TICK()).to.eq(887268)
      })
      it('initialize sets min and max ticks', async () => {
        await initialize(encodePriceSqrt(1, 1))
        const {liquidityGross: minTickLiquidityGross} = await pair.tickInfos(-887268)
        const {liquidityGross: maxTickLiquidityGross} = await pair.tickInfos(887268)
        expect(minTickLiquidityGross).to.eq(1)
        expect(minTickLiquidityGross).to.eq(maxTickLiquidityGross)
      })
      describe('post initialize', () => {
        beforeEach('initialize pair', async () => {
          await initialize(encodePriceSqrt(1, 1))
        })
        it('mint can only be called for multiples of 12', async () => {
          await expect(mint(walletAddress, -6, 0, 1)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: tickSpacing must evenly divide tickLower'
          )
          await expect(mint(walletAddress, 0, 6, 1)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: tickSpacing must evenly divide tickUpper'
          )
        })
        it('mint can be called with multiples of 12', async () => {
          await mint(walletAddress, 12, 24, 1)
          await mint(walletAddress, -144, -120, 1)
        })
        it('swapping across gaps works in 1 for 0 direction', async () => {
          const liquidityAmount = expandTo18Decimals(1).div(4)
          await mint(walletAddress, 120000, 121200, liquidityAmount)
          await swapExact1For0(expandTo18Decimals(1), walletAddress)
          await expect(pair.burn(walletAddress, 120000, 121200, liquidityAmount))
            .to.emit(token0, 'Transfer')
            .withArgs(pair.address, walletAddress, '30027458295511')
            .to.emit(token1, 'Transfer')
            .withArgs(pair.address, walletAddress, '996999999999999535')
          expect(await pair.tickCurrent()).to.eq(120196)
        })
        it('swapping across gaps works in 0 for 1 direction', async () => {
          const liquidityAmount = expandTo18Decimals(1).div(4)
          await mint(walletAddress, -121200, -120000, liquidityAmount)
          await swapExact0For1(expandTo18Decimals(1), walletAddress)
          await expect(pair.burn(walletAddress, -121200, -120000, liquidityAmount))
            .to.emit(token0, 'Transfer')
            .withArgs(pair.address, walletAddress, '996999999999999535')
            .to.emit(token1, 'Transfer')
            .withArgs(pair.address, walletAddress, '30027458295511')
          expect(await pair.tickCurrent()).to.eq(-120197)
        })
      })
    })
  })

  // https://github.com/Uniswap/uniswap-v3-core/issues/214
  it('tick transition cannot run twice if zero for one swap ends at fractional price just below tick', async () => {
    pair = await createPair(FeeAmount.MEDIUM, 1)
    const sqrtTickMath = (await (await ethers.getContractFactory('SqrtTickMathTest')).deploy()) as SqrtTickMathTest
    const swapMath = (await (await ethers.getContractFactory('SwapMathTest')).deploy()) as SwapMathTest
    const p0 = (await sqrtTickMath.getSqrtRatioAtTick(-24081))._x.add(1)
    // initialize at a price of ~0.3 token1/token0
    // meaning if you swap in 2 token0, you should end up getting 0 token1
    await initialize(p0)
    expect(await pair.liquidityCurrent(), 'current pair liquidity is 1').to.eq(1)
    expect(await pair.tickCurrent(), 'pair tick is -24081').to.eq(-24081)

    // add a bunch of liquidity around current price
    const liquidity = expandTo18Decimals(1000)
    await mint(walletAddress, -24082, -24080, liquidity)
    expect(await pair.liquidityCurrent(), 'current pair liquidity is now liquidity + 1').to.eq(liquidity.add(1))

    await mint(walletAddress, -24082, -24081, liquidity)
    expect(await pair.liquidityCurrent(), 'current pair liquidity is still liquidity + 1').to.eq(liquidity.add(1))

    const {secondsOutside: secondsOutsideBefore} = await pair.tickInfos(-24081)

    // check the math works out to moving the price down 1, sending no amount out, and having some amount remaining
    {
      const {feeAmount, amountIn, amountOut, sqrtQ} = await swapMath.computeSwapStep(
        {_x: p0},
        {_x: p0.sub(1)},
        liquidity.add(1),
        3,
        FeeAmount.MEDIUM
      )
      expect(sqrtQ._x, 'price moves').to.eq(p0.sub(1))
      expect(feeAmount, 'fee amount is 1').to.eq(1)
      expect(amountIn, 'amount in is 1').to.eq(1)
      expect(amountOut, 'zero amount out').to.eq(0)
    }

    // swap 2 amount in, should get 0 amount out
    await expect(swapExact0For1(3, walletAddress))
      .to.emit(token0, 'Transfer')
      .withArgs(walletAddress, pair.address, 3)
      .to.emit(token1, 'Transfer')
      .withArgs(pair.address, walletAddress, 0)

    const {secondsOutside: secondsOutsideAfter} = await pair.tickInfos(-24081)

    expect(await pair.tickCurrent(), 'pair is at the next tick').to.eq(-24082)
    expect(await pair.sqrtPriceCurrent(), 'pair price is in the next tick').to.eq(p0.sub(2))
    expect(await pair.liquidityCurrent(), 'pair has run tick transition and liquidity changed').to.eq(
      liquidity.mul(2).add(1)
    )
    expect(secondsOutsideAfter, 'the tick transition did not run').to.not.eq(secondsOutsideBefore)
  })
})
