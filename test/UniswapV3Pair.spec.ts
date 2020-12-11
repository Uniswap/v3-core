import {ethers, waffle} from 'hardhat'
import {BigNumber, BigNumberish, constants, Signer} from 'ethers'
import {TestERC20} from '../typechain/TestERC20'
import {UniswapV3Factory} from '../typechain/UniswapV3Factory'
import {MockTimeUniswapV3Pair} from '../typechain/MockTimeUniswapV3Pair'
import {TestUniswapV3Callee} from '../typechain/TestUniswapV3Callee'
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
} from './shared/utilities'
import {TickMathTest} from '../typechain/TickMathTest'

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
  let tickMath: TickMathTest
  let testCallee: TestUniswapV3Callee

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPair: ThenArg<ReturnType<typeof pairFixture>>['createPair']

  before('get wallet and other', async () => {
    ;[wallet, other] = await ethers.getSigners()
    ;[walletAddress, otherAddress] = await Promise.all([wallet.getAddress(), other.getAddress()])
    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy fixture', async () => {
    ;({token0, token1, token2, factory, createPair, testCallee, tickMath} = await loadFixture(pairFixture))
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
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(encodePriceSqrt(1, 1))
      await expect(pair.initialize(encodePriceSqrt(1, 1))).to.be.revertedWith(
        'UniswapV3Pair::initialize: pair already initialized'
      )
    })
    it('fails if starting price is too low', async () => {
      await expect(pair.initialize(0)).to.be.revertedWith('SqrtTickMath::getSqrtRatioAtTick: invalid sqrtP')
    })
    it('fails if starting price is too high', async () => {
      await expect(pair.initialize(BigNumber.from(2).pow(128).sub(1))).to.be.revertedWith(
        'SqrtTickMath::getSqrtRatioAtTick: invalid sqrtP'
      )
    })
    it('fails if cannot transfer from user', async () => {
      await expect(pair.initialize(encodePriceSqrt(1, 1))).to.be.revertedWith(
        'TransferHelper::transferFrom: transferFrom failed'
      )
    })
    it('sets initial variables', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      const price = encodePriceSqrt(1, 2)
      await pair.initialize(price)
      expect(await pair.sqrtPriceCurrent()).to.eq(price)
      expect(await pair.blockTimestampLast()).to.eq(TEST_PAIR_START_TIME)
      expect(await pair.tickCurrent()).to.eq(-6932)
      expect(await pair.liquidityCurrent()).to.eq(1)
    })
    it('initializes MIN_TICK and MAX_TICK', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      const price = encodePriceSqrt(1, 2)
      await pair.initialize(price)

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
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      const price = encodePriceSqrt(1, 2)
      await pair.initialize(price)
      const {liquidity} = await pair.positions(getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK))
      expect(liquidity).to.eq(1)
    })
    it('emits a Initialized event with the input tick', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      const price = encodePriceSqrt(1, 2)
      await expect(pair.initialize(price)).to.emit(pair, 'Initialized').withArgs(price)
    })
    it('transfers the token', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      const price = encodePriceSqrt(1, 2)
      await expect(pair.initialize(price))
        .to.emit(token0, 'Transfer')
        .withArgs(walletAddress, pair.address, 2)
        .to.emit(token1, 'Transfer')
        .withArgs(walletAddress, pair.address, 1)
      expect(await token0.balanceOf(pair.address)).to.eq(2)
      expect(await token1.balanceOf(pair.address)).to.eq(1)
    })
  })

  describe('#setPosition', () => {
    it('fails if not initialized', async () => {
      await expect(pair.setPosition(-tickSpacing, tickSpacing, 0)).to.be.revertedWith(
        'UniswapV3Pair::setPosition: pair not initialized'
      )
    })
    describe('after initialization', () => {
      beforeEach('initialize the pair at price of 10:1', async () => {
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.initialize(encodePriceSqrt(1, 10))
        await pair.setPosition(MIN_TICK, MAX_TICK, 3161)
        await token0.approve(pair.address, 0)
        await token1.approve(pair.address, 0)
      })

      describe('failure cases', () => {
        it('fails if tickLower greater than tickUpper', async () => {
          await expect(pair.setPosition(1, 0, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickLower must be less than tickUpper'
          )
        })
        it('fails if tickLower less than min tick', async () => {
          await expect(pair.setPosition(MIN_TICK - 1, 0, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickLower cannot be less than min tick'
          )
        })
        it('fails if tickUpper greater than max tick', async () => {
          await expect(pair.setPosition(0, MAX_TICK + 1, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickUpper cannot be greater than max tick'
          )
        })
        it('fails if cannot transfer', async () => {
          await expect(pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)).to.be.revertedWith(
            'TransferHelper::transferFrom: transferFrom failed'
          )
        })
        it('fails if called with 0 liquidityDelta for empty position', async () => {
          await expect(pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 0)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: cannot collect fees on 0 liquidity position'
          )
        })
        it('fails if called with 0 liquidityDelta for empty position', async () => {
          await expect(pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 0)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: cannot collect fees on 0 liquidity position'
          )
        })
        it('fails if called with negative liquidityDelta gt position liquidity', async () => {
          await expect(pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, -1)).to.be.revertedWith(
            'UniswapV3Pair::_updatePosition: cannot remove more than current position liquidity'
          )
        })
        it('fails if liquidityDelta exceeds the max', async () => {
          await expect(
            pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, MAX_LIQUIDITY_GROSS_PER_TICK.add(1))
          ).to.be.revertedWith('UniswapV3Pair::_updatePosition: liquidity overflow in lower tick')
        })
      })

      describe('success cases', () => {
        it('initial prices', async () => {
          expect(await token0.balanceOf(pair.address)).to.eq(10000)
          expect(await token1.balanceOf(pair.address)).to.eq(1001)
        })

        beforeEach('approve the max uint', async () => {
          await token0.approve(pair.address, constants.MaxUint256)
          await token1.approve(pair.address, constants.MaxUint256)
        })

        describe('below current price', () => {
          it('transfers token0 only', async () => {
            await expect(pair.setPosition(-22980, 0, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 21549)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 21549)
            expect(await token1.balanceOf(pair.address)).to.eq(1001)
          })

          it('works for max tick', async () => {
            await expect(pair.setPosition(-22980, MAX_TICK, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 31549)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 31549)
            expect(await token1.balanceOf(pair.address)).to.eq(1001)
          })

          it('removing works', async () => {
            await pair.setPosition(-240, 0, 10000)
            await pair.setPosition(-240, 0, -10000)
            expect(await token0.balanceOf(pair.address)).to.eq(10001)
            expect(await token1.balanceOf(pair.address)).to.eq(1001)
          })

          it('adds liquidity to liquidityGross', async () => {
            await pair.setPosition(-240, 0, 100)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(100)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(100)
            expect((await pair.tickInfos(tickSpacing)).liquidityGross).to.eq(0)
            expect((await pair.tickInfos(tickSpacing * 2)).liquidityGross).to.eq(0)
            await pair.setPosition(-240, tickSpacing, 150)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(250)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(100)
            expect((await pair.tickInfos(tickSpacing)).liquidityGross).to.eq(150)
            expect((await pair.tickInfos(tickSpacing * 2)).liquidityGross).to.eq(0)
            await pair.setPosition(0, tickSpacing * 2, 60)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(250)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(160)
            expect((await pair.tickInfos(tickSpacing)).liquidityGross).to.eq(150)
            expect((await pair.tickInfos(tickSpacing * 2)).liquidityGross).to.eq(60)
          })

          it('removes liquidity from liquidityGross', async () => {
            await pair.setPosition(-240, 0, 100)
            await pair.setPosition(-240, 0, 40)
            await pair.setPosition(-240, 0, -90)
            expect((await pair.tickInfos(-240)).liquidityGross).to.eq(50)
            expect((await pair.tickInfos(0)).liquidityGross).to.eq(50)
          })

          it('clears tick lower if last position is removed', async () => {
            await pair.setPosition(-240, 0, 100)
            await pair.setPosition(-240, 0, -100)
            const {liquidityGross, feeGrowthOutside0, feeGrowthOutside1, secondsOutside} = await pair.tickInfos(-240)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0._x).to.eq(0)
            expect(feeGrowthOutside1._x).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })

          it('clears tick upper if last position is removed', async () => {
            await pair.setPosition(-240, 0, 100)
            await pair.setPosition(-240, 0, -100)
            const {liquidityGross, feeGrowthOutside0, feeGrowthOutside1, secondsOutside} = await pair.tickInfos(0)
            expect(liquidityGross).to.eq(0)
            expect(feeGrowthOutside0._x).to.eq(0)
            expect(feeGrowthOutside1._x).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })
          it('only clears the tick that is not used at all', async () => {
            await pair.setPosition(-240, 0, 100)
            await pair.setPosition(-tickSpacing, 0, 250)
            await pair.setPosition(-240, 0, -100)

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
            await snapshotGasCost(pair.setPosition(-240, 0, 10000))
          })
        })

        describe('including current price', () => {
          it('price within range: transfers current price of both tokens', async () => {
            await expect(pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 317)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 32)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 317)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 32)
          })

          it('initializes lower tick', async () => {
            await pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            const {liquidityGross, secondsOutside} = await pair.tickInfos(MIN_TICK + tickSpacing)
            expect(liquidityGross).to.eq(100)
            expect(secondsOutside).to.eq(TEST_PAIR_START_TIME)
          })

          it('initializes upper tick', async () => {
            await pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            const {liquidityGross, secondsOutside} = await pair.tickInfos(MAX_TICK - tickSpacing)
            expect(liquidityGross).to.eq(100)
            expect(secondsOutside).to.eq(0)
          })

          it('works for min/max tick', async () => {
            await expect(pair.setPosition(MIN_TICK, MAX_TICK, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 31623)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 3163)
            expect(await token0.balanceOf(pair.address)).to.eq(10000 + 31623)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 3163)
          })

          it('removing works', async () => {
            await pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100)
            await pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, -100)
            expect(await token0.balanceOf(pair.address)).to.eq(10001)
            expect(await token1.balanceOf(pair.address)).to.eq(1002)
          })

          it('gas', async () => {
            await snapshotGasCost(pair.setPosition(MIN_TICK + tickSpacing, MAX_TICK - tickSpacing, 100))
          })
        })

        describe('above current price', () => {
          it('transfers token1 only', async () => {
            await expect(pair.setPosition(-46080, -23040, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 2162)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 2162)
          })

          it('works for min tick', async () => {
            await expect(pair.setPosition(MIN_TICK, -23040, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 3161)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(1001 + 3161)
          })

          it('removing works', async () => {
            await pair.setPosition(-46080, -46020, 10000)
            await pair.setPosition(-46080, -46020, -10000)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(1002)
          })

          it('gas', async () => {
            await snapshotGasCost(await pair.setPosition(-46080, -46020, 10000))
          })
        })
      })
    })
  })

  // the combined amount of liquidity that the pair is initialized with (including the 1 minimum liquidity that is burned)
  const initializeLiquidityAmount = expandTo18Decimals(2)
  async function initializeAtZeroTick(pair: MockTimeUniswapV3Pair): Promise<void> {
    await token0.approve(pair.address, initializeLiquidityAmount)
    await token1.approve(pair.address, initializeLiquidityAmount)
    await pair.initialize(encodePriceSqrt(1, 1))
    const [min, max] = await Promise.all([pair.MIN_TICK(), pair.MAX_TICK()])
    await pair.setPosition(min, max, initializeLiquidityAmount.sub(1))
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
        await token0.approve(pair.address, 1000)
        await pair.swap0For1(1000, walletAddress, '0x')
        await pair.setTime(TEST_PAIR_START_TIME + 4)
        let {tickCumulative} = await pair.getCumulatives()
        expect(tickCumulative).to.eq(-4)
      })

      it('tick accumulator after two swaps', async () => {
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.swap0For1(expandTo18Decimals(1).div(2), walletAddress, '0x')
        expect(await pair.tickCurrent()).to.eq(-4452)
        await pair.setTime(TEST_PAIR_START_TIME + 4)
        await pair.swap1For0(expandTo18Decimals(1).div(4), walletAddress, '0x')
        expect(await pair.tickCurrent()).to.eq(-1558)
        await pair.setTime(TEST_PAIR_START_TIME + 10)
        let {tickCumulative} = await pair.getCumulatives()
        // -4452*4 + -1558*6
        expect(tickCumulative).to.eq(-27156)
      })
    })
  })

  describe('callee', () => {
    beforeEach(() => initializeAtZeroTick(pair))
    it('swap0For1 calls the callee', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(1000, testCallee.address, '0xabcd'))
        .to.emit(testCallee, 'Swap0For1Callback')
        .withArgs(pair.address, walletAddress, 996, '0xabcd')
    })

    it('swap1For0 calls the callee', async () => {
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap1For0(1000, testCallee.address, '0xdeff'))
        .to.emit(testCallee, 'Swap1For0Callback')
        .withArgs(pair.address, walletAddress, 996, '0xdeff')
    })
  })

  // TODO test rest of categories in a loop to reduce code duplication
  describe('post-initialize for low fee', () => {
    beforeEach('initialize at zero tick', async () => {
      pair = await createPair(FeeAmount.LOW, TICK_SPACINGS[FeeAmount.LOW])
      await initializeAtZeroTick(pair)
    })

    describe('with fees', async () => {
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing * 4
      const liquidityDelta = expandTo18Decimals(1000)

      beforeEach('provide 1 liquidity in the range -1 to 4', async () => {
        // approve max
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)

        // the LP provides some liquidity in specified tick range
        await pair.setPosition(lowerTick, upperTick, liquidityDelta)
      })

      beforeEach('swap in 2 token0', async () => {
        await pair.swap0For1(expandTo18Decimals(2), walletAddress, '0x')
      })

      // TODO add more tests here

      it('setPosition with 0 liquidity claims fees', async () => {
        const token0Before = await token0.balanceOf(walletAddress)
        const token1Before = await token1.balanceOf(walletAddress)
        await pair.setPosition(lowerTick, upperTick, 0)
        expect(await token0.balanceOf(walletAddress)).to.be.gt(token0Before)
        expect(await token1.balanceOf(walletAddress)).to.be.eq(token1Before)
      })
    })

    it('setPosition to the right of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = tickSpacing
      const upperTick = tickSpacing * 2

      const k = await pair.liquidityCurrent()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await token0.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(3)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(0)
    })

    it('setPosition to the left of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -tickSpacing * 2
      const upperTick = -tickSpacing

      const k = await pair.liquidityCurrent()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(0)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(3)
    })

    it('setPosition within the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing

      const k = await pair.liquidityCurrent()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta)

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(3)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(3)
    })

    it('cannot remove more than the entire position', async () => {
      const lowerTick = -tickSpacing
      const upperTick = tickSpacing
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, expandTo18Decimals(1000))
      await expect(pair.setPosition(lowerTick, upperTick, expandTo18Decimals(-1001))).to.be.revertedWith(
        'UniswapV3Pair::_updatePosition: cannot remove more than current position liquidity'
      )
    })

    it('swap0For1', async () => {
      const amount0In = 1000

      const token0BalanceBefore = await token0.balanceOf(walletAddress)
      const token1BalanceBefore = await token1.balanceOf(walletAddress)

      await token0.approve(pair.address, constants.MaxUint256)
      await pair.swap0For1(amount0In, walletAddress, '0x')

      const token0BalanceAfter = await token0.balanceOf(walletAddress)
      const token1BalanceAfter = await token1.balanceOf(walletAddress)

      expect(token0BalanceBefore.sub(token0BalanceAfter), 'token0 balance decreases by amount in').to.eq(amount0In)
      expect(token1BalanceAfter.sub(token1BalanceBefore), 'token1 balance increases by expected amount out').to.eq(998)

      expect(await pair.tickCurrent()).to.eq(-1)
    })

    it('swap0For1 gas', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await snapshotGasCost(pair.swap0For1(1000, walletAddress, '0x'))
    })

    it('swap0For1 gas large swap', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await snapshotGasCost(pair.swap0For1(expandTo18Decimals(1), walletAddress, '0x'))
    })

    it('swap0For1 large swap crossing several initialized ticks', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(-tickSpacing * 2, -tickSpacing, expandTo18Decimals(1))
      await pair.setPosition(-tickSpacing * 4, -tickSpacing * 2, expandTo18Decimals(1))

      await expect(pair.swap0For1(expandTo18Decimals(1), walletAddress, '0x'))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '671288525725295030')
    })

    it('swap0For1 gas large swap crossing several initialized ticks', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(-tickSpacing * 2, -tickSpacing, expandTo18Decimals(1))
      await pair.setPosition(-tickSpacing * 4, -tickSpacing * 2, expandTo18Decimals(1))

      await snapshotGasCost(pair.swap0For1(expandTo18Decimals(1), walletAddress, '0x'))
    })

    it('swap1For0', async () => {
      const amount1In = 1000

      const token0BalanceBefore = await token0.balanceOf(walletAddress)
      const token1BalanceBefore = await token1.balanceOf(walletAddress)

      await token1.approve(pair.address, constants.MaxUint256)
      await pair.swap1For0(amount1In, walletAddress, '0x')

      const token0BalanceAfter = await token0.balanceOf(walletAddress)
      const token1BalanceAfter = await token1.balanceOf(walletAddress)

      expect(token0BalanceAfter.sub(token0BalanceBefore), 'output amount increased by expected swap output').to.eq(998)
      expect(token1BalanceBefore.sub(token1BalanceAfter), 'input amount decreased by amount in').to.eq(amount1In)

      expect(await pair.tickCurrent()).to.eq(0)
    })

    it('swap1For0 gas', async () => {
      await token1.approve(pair.address, constants.MaxUint256)
      await snapshotGasCost(pair.swap1For0(1000, walletAddress, '0x'))
    })

    it('swap1For0 gas large swap', async () => {
      await token1.approve(pair.address, constants.MaxUint256)
      await snapshotGasCost(pair.swap1For0(expandTo18Decimals(1), walletAddress, '0x'))
    })

    it('swap1For0 large swap crossing several initialized ticks', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(tickSpacing, tickSpacing * 2, expandTo18Decimals(1))
      await pair.setPosition(tickSpacing * 2, tickSpacing * 4, expandTo18Decimals(1))

      await expect(pair.swap1For0(expandTo18Decimals(1), walletAddress, '0x'))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '671288525725295031')
    })

    it('swap1For0 gas large swap crossing several initialized ticks', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(tickSpacing, tickSpacing * 2, expandTo18Decimals(1))
      await pair.setPosition(tickSpacing * 2, tickSpacing * 4, expandTo18Decimals(1))

      await snapshotGasCost(pair.swap1For0(expandTo18Decimals(1), walletAddress, '0x'))
    })

    it('setPosition with 0 liquidityDelta within the current price after swap must collect fees', async () => {
      let liquidityDelta = expandTo18Decimals(100)
      const lowerTick = -tickSpacing * 100
      const upperTick = tickSpacing * 100

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(lowerTick, upperTick, liquidityDelta)

      const k = await pair.liquidityCurrent()

      const amount0In = expandTo18Decimals(1)
      await pair.swap0For1(amount0In, walletAddress, '0x')

      const kAfter = await pair.liquidityCurrent()
      expect(kAfter, 'k increases').to.be.gte(k)

      const token0BalanceBeforePair = await token0.balanceOf(pair.address)
      const token1BalanceBeforePair = await token1.balanceOf(pair.address)
      const token0BalanceBeforeWallet = await token0.balanceOf(walletAddress)
      const token1BalanceBeforeWallet = await token1.balanceOf(walletAddress)

      await pair.setPosition(lowerTick, upperTick, 0)

      const {amount0, amount1} = await pair.callStatic.setPosition(lowerTick, upperTick, 0)
      expect(amount0).to.be.eq(0)
      expect(amount1).to.be.eq(0)

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
    beforeEach('initialize the pair', async () => {
      await initializeAtZeroTick(pair)
    })

    it('swap0For1', async () => {
      const amount0In = 1000

      const token0BalanceBefore = await token0.balanceOf(walletAddress)
      const token1BalanceBefore = await token1.balanceOf(walletAddress)

      await token0.approve(pair.address, constants.MaxUint256)
      await pair.swap0For1(amount0In, walletAddress, '0x')

      const token0BalanceAfter = await token0.balanceOf(walletAddress)
      const token1BalanceAfter = await token1.balanceOf(walletAddress)

      expect(token0BalanceBefore.sub(token0BalanceAfter)).to.eq(amount0In)
      expect(token1BalanceAfter.sub(token1BalanceBefore)).to.eq(996)

      expect(await pair.tickCurrent()).to.eq(-1)
    })

    it('swap0For1 to tick -1k', async () => {
      const amount0In = expandTo18Decimals(1).div(10)

      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(amount0In, walletAddress, '0x'))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '94965947516311854')

      expect(await pair.tickCurrent()).to.eq(-973)
    })

    it('swap0For1 to tick -1k with intermediate liquidity', async () => {
      const amount0In = expandTo18Decimals(1).div(10)

      // add liquidity between -3 and -2 (to the left of the current price)
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = -tickSpacing * 2
      const upperTick = -tickSpacing
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta)

      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(amount0In, walletAddress, '0x'))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '95214395213460208')

      expect(await pair.tickCurrent()).to.eq(-945)
    })

    it('swap1For0', async () => {
      const amount1In = 1000

      const token0BalanceBefore = await token0.balanceOf(walletAddress)
      const token1BalanceBefore = await token1.balanceOf(walletAddress)

      await token1.approve(pair.address, constants.MaxUint256)
      await pair.swap1For0(amount1In, walletAddress, '0x')

      const token0BalanceAfter = await token0.balanceOf(walletAddress)
      const token1BalanceAfter = await token1.balanceOf(walletAddress)

      expect(token0BalanceAfter.sub(token0BalanceBefore)).to.eq(996)
      expect(token1BalanceBefore.sub(token1BalanceAfter)).to.eq(amount1In)

      expect(await pair.tickCurrent()).to.eq(0)
    })

    it('swap1For0 to tick 1k', async () => {
      const amount1In = expandTo18Decimals(1).div(10)

      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap1For0(amount1In, walletAddress, '0x'))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '94965947516311854')

      expect(await pair.tickCurrent()).to.eq(972)
    })

    it('swap1For0 to tick 1k with intermediate liquidity', async () => {
      const amount1In = expandTo18Decimals(1).div(10)

      // add liquidity between 2 and 3 (to the right of the current price)
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = tickSpacing
      const upperTick = tickSpacing * 2
      await token0.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta)

      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap1For0(amount1In, walletAddress, '0x'))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '95214395213460209')

      expect(await pair.tickCurrent()).to.eq(944)
    })
  })

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
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.setPosition(-tickSpacing, tickSpacing, expandTo18Decimals(3))
        expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(5))
      })
      it('excludes supply at tick above current tick', async () => {
        await token0.approve(pair.address, constants.MaxUint256)
        await pair.setPosition(tickSpacing, tickSpacing * 2, expandTo18Decimals(3))
        expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(2))
      })
      it('excludes supply at tick below current tick', async () => {
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.setPosition(-tickSpacing * 2, -tickSpacing, expandTo18Decimals(3))
        expect(await pair.liquidityCurrent()).to.eq(expandTo18Decimals(2))
      })
      it('updates correctly when exiting range', async () => {
        const kBefore = await pair.liquidityCurrent()
        expect(kBefore).to.be.eq(expandTo18Decimals(2))

        // add liquidity at and above current tick
        const liquidityDelta = expandTo18Decimals(1)
        const lowerTick = 0
        const upperTick = tickSpacing
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.setPosition(lowerTick, upperTick, liquidityDelta)

        // ensure virtual supply has increased appropriately
        const kAfter = await pair.liquidityCurrent()
        expect(kAfter).to.be.gt(kBefore)
        expect(kAfter).to.be.eq(expandTo18Decimals(3))

        // swap toward the left (just enough for the tick transition function to trigger)
        // TODO if the input amount is 1 here, the tick transition fires incorrectly!
        // should throw an error or something once the TODOs in pair are fixed
        await pair.swap0For1(2, walletAddress, '0x')
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
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.setPosition(lowerTick, upperTick, liquidityDelta)

        // ensure virtual supply hasn't changed
        const kAfter = await pair.liquidityCurrent()
        expect(kAfter).to.be.eq(kBefore)

        // swap toward the left (just enough for the tick transition function to trigger)
        // TODO if the input amount is 1 here, the tick transition fires incorrectly!
        // should throw an error or something once the TODOs in pair are fixed
        await pair.swap0For1(2, walletAddress, '0x')
        const tick = await pair.tickCurrent()
        expect(tick).to.be.eq(-1)

        const kAfterSwap = await pair.liquidityCurrent()
        expect(kAfterSwap).to.be.gt(kAfter)
        // TODO not sure this is right
        expect(kAfterSwap).to.be.eq(expandTo18Decimals(3))
      })
    })
  })

  describe('limit orders', () => {
    beforeEach('initialize at tick 0', () => initializeAtZeroTick(pair))

    beforeEach('approve the pair', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
    })

    it('selling 1 for 0 at tick 0 thru 1', async () => {
      await expect(pair.setPosition(0, 120, expandTo18Decimals(1)))
        .to.emit(token0, 'Transfer')
        .withArgs(walletAddress, pair.address, '5981737760509663')
      // somebody takes the limit order
      await pair.swap1For0(expandTo18Decimals(2), otherAddress, '0x')
      await expect(pair.setPosition(0, 120, expandTo18Decimals(1).mul(-1)))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '6035841794200767')
    })
    it('selling 0 for 1 at tick 0 thru -1', async () => {
      await expect(pair.setPosition(-120, 0, expandTo18Decimals(1)))
        .to.emit(token1, 'Transfer')
        .withArgs(walletAddress, pair.address, '5981737760509663')
      // somebody takes the limit order
      await pair.swap0For1(expandTo18Decimals(2), otherAddress, '0x')
      await expect(pair.setPosition(-120, 0, expandTo18Decimals(1).mul(-1)))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '6035841794200767')
    })

    describe('fee is on', () => {
      beforeEach(() => pair.setFeeTo(walletAddress))
      it('selling 1 for 0 at tick 0 thru 1', async () => {
        await expect(pair.setPosition(0, 120, expandTo18Decimals(1)))
          .to.emit(token0, 'Transfer')
          .withArgs(walletAddress, pair.address, '5981737760509663')
        // somebody takes the limit order
        await pair.swap1For0(expandTo18Decimals(2), otherAddress, '0x')
        await expect(pair.setPosition(0, 120, expandTo18Decimals(1).mul(-1)))
          .to.emit(token1, 'Transfer')
          .withArgs(pair.address, walletAddress, '6032823873303667')
      })
      it('selling 0 for 1 at tick 0 thru -1', async () => {
        await expect(pair.setPosition(-120, 0, expandTo18Decimals(1)))
          .to.emit(token1, 'Transfer')
          .withArgs(walletAddress, pair.address, '5981737760509663')
        // somebody takes the limit order
        await pair.swap0For1(expandTo18Decimals(2), otherAddress, '0x')
        await expect(pair.setPosition(-120, 0, expandTo18Decimals(1).mul(-1)))
          .to.emit(token0, 'Transfer')
          .withArgs(pair.address, walletAddress, '6032823873303667')
      })
    })
  })

  describe('#feeTo', () => {
    const liquidityAmount = expandTo18Decimals(1000)

    beforeEach(async () => {
      pair = await createPair(FeeAmount.LOW, TICK_SPACINGS[FeeAmount.LOW])
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(encodePriceSqrt(1, 1))
      await pair.setPosition(MIN_TICK, MAX_TICK, liquidityAmount)
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
      await (zeroForOne
        ? pair.swap0For1(swapAmount, walletAddress, '0x')
        : pair.swap1For0(swapAmount, walletAddress, '0x'))

      const {amount0, amount1} = await pair.callStatic.setPosition(MIN_TICK, MAX_TICK, 0)

      expect(amount0, 'fees owed in token0 are greater than 0').to.be.lte(0)
      expect(amount1, 'fees owed in token1 are greater than 0').to.be.lte(0)

      return {token0Fees: amount0.mul(-1), token1Fees: amount1.mul(-1)}
    }

    it('position owner gets full fees when protocol fee is off', async () => {
      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      // 6 bips * 1e18
      expect(token0Fees).to.eq('600000000000009')
      expect(token1Fees).to.eq(0)
    })

    it('position owner gets partial fees when protocol fee is on', async () => {
      await pair.setFeeTo(otherAddress)

      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      expect(token0Fees).to.be.eq('500000000000008')
      expect(token1Fees).to.be.eq(0)
    })

    it('fees collected by lp after two swaps should be double one swap', async () => {
      await swapAndGetFeesOwed()
      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      // 6 bips * 2e18
      expect(token0Fees).to.eq('1200000000000025')
      expect(token1Fees).to.eq(0)
    })

    it('fees collected after two swaps with fee turned on in middle are fees from both swaps (confiscatory)', async () => {
      await swapAndGetFeesOwed()

      await pair.setFeeTo(otherAddress)

      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      expect(token0Fees).to.eq('1000000000000021')
      expect(token1Fees).to.eq(0)
    })

    it('fees collected by lp after two swaps with intermediate withdrawal', async () => {
      await pair.setFeeTo(otherAddress)

      const {token0Fees, token1Fees} = await swapAndGetFeesOwed()

      expect(token0Fees).to.eq('500000000000008')
      expect(token1Fees).to.eq(0)

      // collect the fees
      await pair.setPosition(MIN_TICK, MAX_TICK, 0)

      const {token0Fees: token0FeesNext, token1Fees: token1FeesNext} = await swapAndGetFeesOwed()

      expect(token0FeesNext).to.eq('500000000000013')
      expect(token1FeesNext).to.eq(0)

      // the fee to fees do not account for uncollected fees yet
      expect(await pair.feeToFees0()).to.be.eq('100000000000001')
      expect(await pair.feeToFees1()).to.be.eq(0)

      await pair.setPosition(MIN_TICK, MAX_TICK, 0)
      expect(await pair.feeToFees0()).to.be.eq('200000000000003')
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
        expect(await pair.MIN_TICK()).to.eq(-689196)
        expect(await pair.MAX_TICK()).to.eq(689196)
      })
      it('initialize sets min and max ticks', async () => {
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)
        await pair.initialize(encodePriceSqrt(1, 1))
        const {liquidityGross: minTickLiquidityGross} = await pair.tickInfos(-689196)
        const {liquidityGross: maxTickLiquidityGross} = await pair.tickInfos(689196)
        expect(minTickLiquidityGross).to.eq(1)
        expect(minTickLiquidityGross).to.eq(maxTickLiquidityGross)
      })
      describe('post initialize', () => {
        beforeEach('initialize pair', async () => {
          await token0.approve(pair.address, constants.MaxUint256)
          await token1.approve(pair.address, constants.MaxUint256)
          await pair.initialize(encodePriceSqrt(1, 1))
        })
        it('setPosition can only be called for multiples of 12', async () => {
          await expect(pair.setPosition(-6, 0, 1)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickLower and tickUpper must be multiples of tickSpacing'
          )
          await expect(pair.setPosition(0, 6, 1)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickLower and tickUpper must be multiples of tickSpacing'
          )
        })
        it('setPosition can be called with multiples of 12', async () => {
          await pair.setPosition(12, 24, 1)
          await pair.setPosition(-144, -120, 1)
        })
        it('swapping across gaps works in 1 for 0 direction', async () => {
          const liquidityAmount = expandTo18Decimals(1).div(4)
          await pair.setPosition(120000, 121200, liquidityAmount)
          await pair.swap1For0(expandTo18Decimals(1), walletAddress, '0x')
          await expect(pair.setPosition(120000, 121200, liquidityAmount.mul(-1)))
            .to.emit(token0, 'Transfer')
            .withArgs(pair.address, walletAddress, '30027458295511')
            .to.emit(token1, 'Transfer')
            .withArgs(pair.address, walletAddress, '999999999999999533')
          expect(await pair.tickCurrent()).to.eq(120196)
        })
        it('swapping across gaps works in 0 for 1 direction', async () => {
          const liquidityAmount = expandTo18Decimals(1).div(4)
          await pair.setPosition(-121200, -120000, liquidityAmount)
          await pair.swap0For1(expandTo18Decimals(1), walletAddress, '0x')
          await expect(pair.setPosition(-121200, -120000, liquidityAmount.mul(-1)))
            .to.emit(token0, 'Transfer')
            .withArgs(pair.address, walletAddress, '999999999999999532')
            .to.emit(token1, 'Transfer')
            .withArgs(pair.address, walletAddress, '30027458295511')
          expect(await pair.tickCurrent()).to.eq(-120197)
        })
      })
    })
  })
})
