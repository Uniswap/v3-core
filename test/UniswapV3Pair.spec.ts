import {ethers} from 'hardhat'
import {BigNumber, constants, Contract, Signer} from 'ethers'
import {TestERC20} from '../typechain/TestERC20'
import {UniswapV3Factory} from '../typechain/UniswapV3Factory'
import {MockTimeUniswapV3Pair} from '../typechain/MockTimeUniswapV3Pair'
import {UniswapV3PairTest} from '../typechain/UniswapV3PairTest'
import {TestUniswapV3Callee} from '../typechain/TestUniswapV3Callee'
import {TickMathTest} from '../typechain/TickMathTest'
import {expect} from './shared/expect'

import {pairFixture, TEST_PAIR_START_TIME} from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'

import {expandTo18Decimals, FEES, FeeVote, getPositionKey, MAX_TICK, MIN_TICK} from './shared/utilities'

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
  let pairTest: UniswapV3PairTest
  let testCallee: TestUniswapV3Callee
  let tickMath: TickMathTest

  beforeEach('deploy pair fixture', async () => {
    ;[wallet, other] = await ethers.getSigners()
    ;[walletAddress, otherAddress] = await Promise.all([wallet.getAddress(), other.getAddress()])
    ;({token0, token1, token2, factory, pair, pairTest, testCallee, tickMath} = await pairFixture(wallet))
  })

  // this invariant should always hold true.
  afterEach('check tick matches price', async () => {
    // ensure that the tick always matches the price given by virtual reserves
    const [priceCurrent, tickCurrent] = await Promise.all([pair.priceCurrent(), pair.tickCurrent()])
    if (priceCurrent.eq(0)) {
      expect(tickCurrent).to.eq(0)
    } else {
      const [{_x: tickPrice}, {_x: nextPrice}] = await Promise.all([
        tickMath.getPrice(tickCurrent),
        tickMath.getPrice(tickCurrent + 1),
      ])
      expect(priceCurrent, 'priceCurrent is within tickCurrent and tickCurrent+1 bounds')
        .to.be.gte(tickPrice)
        .and.lt(nextPrice)
    }
  })

  it('constructor initializes immutables', async () => {
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(token0.address)
    expect(await pair.token1()).to.eq(token1.address)
  })

  it('fee options', async () => {
    const num = await pair.NUM_FEE_OPTIONS()
    const options = await Promise.all([...Array(num)].map((_, i) => pair.FEE_OPTIONS(i)))
    expect(options[0]).to.eq(FEES[FeeVote.FeeVote0])
    expect(options[1]).to.eq(FEES[FeeVote.FeeVote1])
    expect(options[2]).to.eq(FEES[FeeVote.FeeVote2])
    expect(options[3]).to.eq(FEES[FeeVote.FeeVote3])
    expect(options[4]).to.eq(FEES[FeeVote.FeeVote4])
    expect(options[5]).to.eq(FEES[FeeVote.FeeVote5])
  })

  describe('#initialize', () => {
    it('fails if already initialized', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(0)
      await expect(pair.initialize(0)).to.be.revertedWith('UniswapV3Pair::initialize: pair already initialized')
    })
    it('fails if tick is less than MIN_TICK', async () => {
      await expect(pair.initialize(MIN_TICK - 1)).to.be.revertedWith(
        'UniswapV3Pair::initialize: tick must be greater than or equal to min tick'
      )
    })
    it('fails if tick is less than MIN_TICK', async () => {
      await expect(pair.initialize(MAX_TICK)).to.be.revertedWith(
        'UniswapV3Pair::initialize: tick must be less than max tick'
      )
    })
    it('fails if cannot transfer from user', async () => {
      await expect(pair.initialize(0)).to.be.revertedWith('TransferHelper::transferFrom: transferFrom failed')
    })
    it('sets initial variables', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(-70)
      expect(await pair.priceCurrent()).to.eq('2587398664091925131144072317295472') // copied from tickmath spec
      expect(await pair.blockTimestampLast()).to.eq(TEST_PAIR_START_TIME)
      expect(await pair.tickCurrent()).to.eq(-70)
      expect(await pair.feeFloor()).to.eq(6)
      expect(await pair.liquidityCurrent(FeeVote.FeeVote0)).to.eq(1)
    })
    it('initializes MIN_TICK and MAX_TICK', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(-70)

      {
        const {numPositions, secondsOutside, feeGrowthOutside0, feeGrowthOutside1} = await pair.tickInfos(MIN_TICK)
        expect(numPositions).to.eq(1)
        expect(secondsOutside).to.eq(1601906400)
        expect(feeGrowthOutside0._x).to.eq(0)
        expect(feeGrowthOutside1._x).to.eq(0)
      }
      {
        const {numPositions, secondsOutside, feeGrowthOutside0, feeGrowthOutside1} = await pair.tickInfos(MAX_TICK)
        expect(numPositions).to.eq(1)
        expect(secondsOutside).to.eq(0)
        expect(feeGrowthOutside0._x).to.eq(0)
        expect(feeGrowthOutside1._x).to.eq(0)
      }
    })
    it('creates a position for address 0 for min liquidity', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(-70)
      const {liquidity} = await pair.positions(
        getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK, FeeVote.FeeVote0)
      )
      expect(liquidity).to.eq(1)
    })
    it('emits a Initialized event with the input tick', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.initialize(-70)).to.emit(pair, 'Initialized').withArgs(-70)
    })
    it('transfers the token', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.initialize(-70))
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
      await expect(pair.setPosition(-1, 1, 0, 0)).to.be.revertedWith('UniswapV3Pair::setPosition: pair not initialized')
    })
    describe('after initialization', () => {
      beforeEach('initialize the pair at price of 10:1 with fee vote 1', async () => {
        await token0.approve(pair.address, 11000)
        await token1.approve(pair.address, 1000)
        await pair.initialize(-232) // about 10k token0 and 1k token1
        await pair.setPosition(MIN_TICK, MAX_TICK, FeeVote.FeeVote1, 3161)
      })

      describe('failure cases', () => {
        it('fails if tickLower greater than tickUpper', async () => {
          await expect(pair.setPosition(1, 0, 0, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickLower must be less than tickUpper'
          )
        })
        it('fails if tickLower less than min tick', async () => {
          await expect(pair.setPosition(MIN_TICK - 1, 1, 0, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickLower cannot be less than min tick'
          )
        })
        it('fails if tickUpper greater than max tick', async () => {
          await expect(pair.setPosition(-1, MAX_TICK + 1, 0, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: tickUpper cannot be greater than max tick'
          )
        })
        it('fails if tickUpper greater than max tick', async () => {
          await expect(pair.setPosition(-1, 1, 6, 0)).to.be.revertedWith(
            'UniswapV3Pair::setPosition: fee vote must be a valid option'
          )
        })
        it('fails if cannot transfer', async () => {
          await expect(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100)).to.be.revertedWith(
            'TransferHelper::transferFrom: transferFrom failed'
          )
        })
      })

      describe('success cases', () => {
        beforeEach('approve the max uint', async () => {
          await token0.approve(pair.address, constants.MaxUint256)
          await token1.approve(pair.address, constants.MaxUint256)
        })

        describe('below current price', () => {
          it('transfers token0 only', async () => {
            await expect(pair.setPosition(-231, 0, 0, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 21559)
            expect(await token0.balanceOf(pair.address)).to.eq(10030 + 21559)
            expect(await token1.balanceOf(pair.address)).to.eq(998)
          })

          it('works for max tick', async () => {
            await expect(pair.setPosition(-231, MAX_TICK, 0, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 31559)
            expect(await token0.balanceOf(pair.address)).to.eq(10030 + 31559)
            expect(await token1.balanceOf(pair.address)).to.eq(998)
          })

          it('removing works', async () => {
            await pair.setPosition(-231, 0, 0, 10000)
            await pair.setPosition(-231, 0, 0, -10000)
            expect(await token0.balanceOf(pair.address)).to.eq(10031) // 1 dust is left over
            expect(await token1.balanceOf(pair.address)).to.eq(998)
          })

          it('increments numPositions', async () => {
            await pair.setPosition(-231, 5, 0, 100)
            expect((await pair.tickInfos(-231))[0]).to.eq(1)
            expect((await pair.tickInfos(5))[0]).to.eq(1)
            await pair.setPosition(-231, 5, 1, 100)
            expect((await pair.tickInfos(-231))[0]).to.eq(2)
            expect((await pair.tickInfos(5))[0]).to.eq(2)
          })

          it('decrements numPositions', async () => {
            await pair.setPosition(-231, 0, 0, 100)
            await pair.setPosition(-231, 0, 1, 100)
            await pair.setPosition(-231, 0, 1, -100)
            expect((await pair.tickInfos(-231))[0]).to.eq(1)
            expect((await pair.tickInfos(0))[0]).to.eq(1)
          })

          it('clears tick if last position is removed', async () => {
            await pair.setPosition(-231, 0, 1, 100)
            await pair.setPosition(-231, 0, 1, -100)
            const {numPositions} = await pair.tickInfos(-231)
            expect(numPositions).to.eq(0)
          })

          it('gas', async () => {
            await snapshotGasCost(pair.setPosition(-231, 0, 0, 10000))
          })
        })

        describe('including current price', () => {
          it('price within range: transfers current price of both tokens', async () => {
            await expect(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 318)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 32)
            expect(await token0.balanceOf(pair.address)).to.eq(10030 + 318)
            expect(await token1.balanceOf(pair.address)).to.eq(998 + 32)
          })

          it('initializes lower tick', async () => {
            await pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100)
            const {numPositions, secondsOutside} = await pair.tickInfos(MIN_TICK + 1)
            expect(numPositions).to.eq(1)
            expect(secondsOutside).to.eq(TEST_PAIR_START_TIME)
          })

          it('initializes upper tick', async () => {
            await pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100)
            const {numPositions, secondsOutside} = await pair.tickInfos(MAX_TICK - 1)
            expect(numPositions).to.eq(1)
            expect(secondsOutside).to.eq(0)
          })

          it('works for min/max tick', async () => {
            await expect(pair.setPosition(MIN_TICK, MAX_TICK, 0, 10000))
              .to.emit(token0, 'Transfer')
              .withArgs(walletAddress, pair.address, 31717)
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 3153)
            expect(await token0.balanceOf(pair.address)).to.eq(10030 + 31717)
            expect(await token1.balanceOf(pair.address)).to.eq(998 + 3153)
          })

          it('removing works', async () => {
            await pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100)
            await pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, -100)
            expect(await token0.balanceOf(pair.address)).to.eq(10031)
            expect(await token1.balanceOf(pair.address)).to.eq(999)
          })

          it('gas', async () => {
            await snapshotGasCost(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100))
          })
        })

        describe('above current price', () => {
          it('transfers token1 only', async () => {
            await expect(pair.setPosition(-500, -233, 0, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 2307)
            expect(await token0.balanceOf(pair.address)).to.eq(10030)
            expect(await token1.balanceOf(pair.address)).to.eq(998 + 2307)
          })

          it('works for min tick', async () => {
            await expect(pair.setPosition(MIN_TICK, -233, 0, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(walletAddress, pair.address, 3138)
            expect(await token0.balanceOf(pair.address)).to.eq(10030)
            expect(await token1.balanceOf(pair.address)).to.eq(998 + 3138)
          })

          it('removing works', async () => {
            await pair.setPosition(-500, -233, 0, 10000)
            await pair.setPosition(-500, -233, 0, -10000)
            expect(await token0.balanceOf(pair.address)).to.eq(10030)
            expect(await token1.balanceOf(pair.address)).to.eq(999)
          })

          it('gas', async () => {
            await snapshotGasCost(await pair.setPosition(-500, -233, 0, 10000))
          })
        })
      })
    })
  })

  // the combined amount of liquidity that the pair is initialized with (including the 1 minimum liquidity that is burned)
  const initializeLiquidityAmount = expandTo18Decimals(2)
  async function initializeAtZeroTick(feeVote: FeeVote, _pair: MockTimeUniswapV3Pair = pair): Promise<void> {
    await token0.approve(_pair.address, constants.MaxUint256)
    await token1.approve(_pair.address, constants.MaxUint256)
    await _pair.initialize(0)
    await _pair.setPosition(MIN_TICK, MAX_TICK, feeVote, initializeLiquidityAmount.sub(1))
    await token0.approve(_pair.address, 0)
    await token1.approve(_pair.address, 0)
  }

  describe('callee', () => {
    beforeEach(() => initializeAtZeroTick(FeeVote.FeeVote0))
    it('swap0For1 calls the callee', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(1000, testCallee.address, '0xabcd'))
        .to.emit(testCallee, 'Swap0For1Callback')
        .withArgs(pair.address, walletAddress, 998, '0xabcd')
    })

    it('swap1For0 calls the callee', async () => {
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap1For0(1000, testCallee.address, '0xdeff'))
        .to.emit(testCallee, 'Swap1For0Callback')
        .withArgs(pair.address, walletAddress, 998, '0xdeff')
    })
  })

  // TODO test rest of categories in a loop to reduce code duplication
  describe('post-initialize (fee vote 1 - 0.12%)', () => {
    const fee = FeeVote.FeeVote1

    beforeEach('initialize at zero tick', async () => {
      await initializeAtZeroTick(fee)
    })

    describe('with fees', async () => {
      const lowerTick = -1
      const upperTick = 4
      const liquidityDelta = expandTo18Decimals(1000)

      beforeEach('provide 1 liquidity in the range -1 to 4', async () => {
        // approve max
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)

        // the LP provides some liquidity in specified tick range
        await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta)
      })

      beforeEach('swap in 2 token0', async () => {
        await pair.swap0For1(expandTo18Decimals(2), walletAddress, '0x')
      })

      // TODO add more tests here

      it('setPosition with 0 liquidity claims fees', async () => {
        const token0Before = await token0.balanceOf(walletAddress)
        const token1Before = await token1.balanceOf(walletAddress)
        await pair.setPosition(lowerTick, upperTick, fee, 0)
        expect(await token0.balanceOf(walletAddress)).to.be.gt(token0Before)
        expect(await token1.balanceOf(walletAddress)).to.be.eq(token1Before)
      })
    })

    it('setPosition to the right of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = 2
      const upperTick = 4

      const k = await pair.getLiquidity()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await token0.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta)

      const kAfter = await pair.getLiquidity()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(10)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(0)
    })

    it('setPosition to the left of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -4
      const upperTick = -2

      const k = await pair.getLiquidity()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta)

      const kAfter = await pair.getLiquidity()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(0)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(10)
    })

    it('setPosition within the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -2
      const upperTick = 2

      const k = await pair.getLiquidity()

      const b0 = await token0.balanceOf(pair.address)
      const b1 = await token1.balanceOf(pair.address)

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta)

      const kAfter = await pair.getLiquidity()
      expect(kAfter).to.be.gte(k)

      expect((await token0.balanceOf(pair.address)).sub(b0)).to.eq(10)
      expect((await token1.balanceOf(pair.address)).sub(b1)).to.eq(10)
    })

    it('cannot remove more than the entire position', async () => {
      const lowerTick = -2
      const upperTick = 2
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, expandTo18Decimals(1000))
      await expect(
        pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, expandTo18Decimals(-1001))
      ).to.be.revertedWith('MixedSafeMath::addi: underflow')
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
      expect(token1BalanceAfter.sub(token1BalanceBefore)).to.eq(997)

      expect(await pair.tickCurrent()).to.eq(-1)
    })

    it('swap0For1 gas', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await snapshotGasCost(pair.swap0For1(1000, walletAddress, '0x'))
    })

    it('swap0For1 gas large swap', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await snapshotGasCost(pair.swap0For1(expandTo18Decimals(1), walletAddress, '0x'))
    }).timeout(300000)

    it('swap1For0', async () => {
      const amount1In = 1000

      const token0BalanceBefore = await token0.balanceOf(walletAddress)
      const token1BalanceBefore = await token1.balanceOf(walletAddress)

      await token1.approve(pair.address, constants.MaxUint256)
      await pair.swap1For0(amount1In, walletAddress, '0x')

      const token0BalanceAfter = await token0.balanceOf(walletAddress)
      const token1BalanceAfter = await token1.balanceOf(walletAddress)

      expect(token0BalanceAfter.sub(token0BalanceBefore), 'output amount increased by expected swap output').to.eq(997)
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
    }).timeout(300000)

    it('setPosition with 0 liquidityDelta within the current price after swap must collect fees', async () => {
      let liquidityDelta = expandTo18Decimals(100)
      const lowerTick = -2
      const upperTick = 2

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, liquidityDelta)
      await pair.setTime(TEST_PAIR_START_TIME + 1) // so the swap uses the new fee

      const k = await pair.getLiquidity()

      const amount0In = expandTo18Decimals(1)
      await pair.swap0For1(amount0In, walletAddress, '0x')

      const kAfter = await pair.getLiquidity()
      expect(kAfter, 'k increases').to.be.gte(k)

      const token0BalanceBeforePair = await token0.balanceOf(pair.address)
      const token1BalanceBeforePair = await token1.balanceOf(pair.address)
      const token0BalanceBeforeWallet = await token0.balanceOf(walletAddress)
      const token1BalanceBeforeWallet = await token1.balanceOf(walletAddress)

      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, 0)

      const {amount0, amount1} = await pair.callStatic.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, 0)
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

  describe('post-initialize (fee vote 2 - 0.30%)', () => {
    const fee = FeeVote.FeeVote2

    beforeEach('initialize the pair', async () => {
      await initializeAtZeroTick(fee)
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

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-1)
    })

    it('swap0For1 to tick -10', async () => {
      const amount0In = expandTo18Decimals(1).div(10)

      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(amount0In, walletAddress, '0x'))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '94965947516311832')

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-10)
    })

    it('swap0For1 to tick -10 with intermediate liquidity', async () => {
      const amount0In = expandTo18Decimals(1).div(10)

      // add liquidity between -3 and -2 (to the left of the current price)
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = -3
      const upperTick = -2
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta)

      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(amount0In, walletAddress, '0x'))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, walletAddress, '95298218973436055')

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-10)
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

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(0)
    })

    it('swap1For0 to tick -10', async () => {
      const amount1In = expandTo18Decimals(1).div(10)

      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap1For0(amount1In, walletAddress, '0x'))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '94965947516311832')

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(9)
    })

    it('swap1For0 to tick -10 with intermediate liquidity', async () => {
      const amount1In = expandTo18Decimals(1).div(10)

      // add liquidity between 2 and 3 (to the right of the current price)
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = 2
      const upperTick = 3
      await token0.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta)

      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap1For0(amount1In, walletAddress, '0x'))
        .to.emit(token0, 'Transfer')
        .withArgs(pair.address, walletAddress, '95298218973436055')

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(9)
    })
  })

  describe('#getCumulativePrices', () => {
    let mockTimePair: MockTimeUniswapV3Pair
    beforeEach('deploy mock pair', async () => {
      const mockTimePairFactory = await ethers.getContractFactory('MockTimeUniswapV3Pair')
      mockTimePair = (await mockTimePairFactory.deploy(
        factory.address,
        token0.address,
        token1.address
      )) as MockTimeUniswapV3Pair
    })
    beforeEach('set pair time to 100', async () => {
      await mockTimePair.setTime(100)
    })
    beforeEach('initialize pair', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote0, mockTimePair)
    })
    beforeEach('approve the pair', async () => {
      await token0.approve(mockTimePair.address, constants.MaxUint256)
      await token1.approve(mockTimePair.address, constants.MaxUint256)
    })
    it('current time is 100', async () => {
      expect(await mockTimePair.time()).to.eq(100)
    })
    it('is initialized', async () => {
      expect(await mockTimePair.isInitialized()).to.eq(true)
    })
    it('current block timestamp is 100', async () => {
      expect(await mockTimePair.blockTimestampLast()).to.eq(100)
    })
    it('cumulative prices are initially 0', async () => {
      const {
        price0Cumulative: {_x: price0},
        price1Cumulative: {_x: price1},
      } = await mockTimePair.getCumulativePrices()
      expect(price0).to.eq(0)
      expect(price1).to.eq(0)
    })
    it('swap without time change does not affect cumulative price', async () => {
      await mockTimePair.swap0For1(100, walletAddress, '0x')
      const {
        price0Cumulative: {_x: price0},
        price1Cumulative: {_x: price1},
      } = await mockTimePair.getCumulativePrices()
      expect(price0).to.eq(0)
      expect(price1).to.eq(0)
    })
    it('swap after time change updates cumulative price', async () => {
      await mockTimePair.setTime(200)
      await mockTimePair.swap0For1(100, walletAddress, '0x')
      const {
        price0Cumulative: {_x: price0},
        price1Cumulative: {_x: price1},
      } = await mockTimePair.getCumulativePrices()
      expect(price0).to.eq(BigNumber.from(2).pow(112).mul(100))
      expect(price1).to.eq(BigNumber.from(2).pow(112).mul(100))
    })
    it('second swap after time change does not affect cumulative price', async () => {
      await mockTimePair.setTime(200)
      await mockTimePair.swap0For1(100, walletAddress, '0x')
      await mockTimePair.swap0For1(100, walletAddress, '0x')
      const {
        price0Cumulative: {_x: price0},
        price1Cumulative: {_x: price1},
      } = await mockTimePair.getCumulativePrices()
      expect(price0).to.eq(BigNumber.from(2).pow(112).mul(100))
      expect(price1).to.eq(BigNumber.from(2).pow(112).mul(100))
    })
    it('third swap after time change adds to cumulative', async () => {
      await mockTimePair.setTime(200)
      await mockTimePair.swap0For1(100, walletAddress, '0x')
      await mockTimePair.setTime(300)
      await mockTimePair.swap0For1(100, walletAddress, '0x')
      const {
        price0Cumulative: {_x: price0},
        price1Cumulative: {_x: price1},
      } = await mockTimePair.getCumulativePrices()
      expect(price0).to.eq('1038459371706965474561975209275969500')
      expect(price1).to.eq('1038459371706965576850223322412073900')
    })
    it('counterfactually computes the cumulative price', async () => {
      await mockTimePair.setTime(200)
      const {
        price0Cumulative: {_x: price0_1},
        price1Cumulative: {_x: price1_1},
      } = await mockTimePair.getCumulativePrices()
      expect(price0_1).to.eq(BigNumber.from(2).pow(112).mul(100))
      expect(price1_1).to.eq(BigNumber.from(2).pow(112).mul(100))
      await mockTimePair.setTime(300)
      const {
        price0Cumulative: {_x: price0_2},
        price1Cumulative: {_x: price1_2},
      } = await mockTimePair.getCumulativePrices()
      expect(price0_2).to.eq(BigNumber.from(2).pow(112).mul(200))
      expect(price1_2).to.eq(BigNumber.from(2).pow(112).mul(200))
    })
  })

  describe('k (implicit)', () => {
    it('returns 0 before initialization', async () => {
      expect(await pair.getLiquidity()).to.eq(0)
    })
    it('returns initial liquidity', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote3)
      expect(await pair.getLiquidity()).to.eq(expandTo18Decimals(2))
    })
    it('returns in supply in range', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote3)
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(-1, 1, FeeVote.FeeVote4, expandTo18Decimals(3))
      expect(await pair.getLiquidity()).to.eq(expandTo18Decimals(5))
    })
    it('excludes supply at tick above current tick', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote3)
      await token0.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(1, 2, FeeVote.FeeVote4, expandTo18Decimals(3))
      expect(await pair.getLiquidity()).to.eq(expandTo18Decimals(2))
    })
    it('excludes supply at tick below current tick', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote3)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(-2, -1, FeeVote.FeeVote4, expandTo18Decimals(3))
      expect(await pair.getLiquidity()).to.eq(expandTo18Decimals(2))
    })
    it('updates correctly when exiting range', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote1)

      const kBefore = await pair.getLiquidity()
      expect(kBefore).to.be.eq(expandTo18Decimals(2))

      // add liquidity at and above current tick
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = 0
      const upperTick = 1
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote1, liquidityDelta)

      // ensure virtual supply has increased appropriately
      const kAFter = await pair.getLiquidity()
      expect(kAFter.gt(kBefore)).to.be.true
      expect(kAFter).to.be.eq(expandTo18Decimals(3))

      // swap toward the left (just enough for the tick transition function to trigger)
      // TODO if the input amount is 1 here, the tick transition fires incorrectly!
      // should throw an error or something once the TODOs in pair are fixed
      await pair.swap0For1(2, walletAddress, '0x')
      const tick = await pair.tickCurrent()
      expect(tick).to.be.eq(-1)

      const kAFterSwap = await pair.getLiquidity()
      expect(kAFterSwap.lt(kAFter)).to.be.true
      // TODO not sure this is right
      expect(kAFterSwap).to.be.eq(expandTo18Decimals(2))
    })
    it('updates correctly when entering range', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote1)

      const kBefore = await pair.getLiquidity()
      expect(kBefore).to.be.eq(expandTo18Decimals(2))

      // add liquidity below the current tick
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = -1
      const upperTick = 0
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote1, liquidityDelta)

      // ensure virtual supply hasn't changed
      const kAfter = await pair.getLiquidity()
      expect(kAfter).to.be.eq(kBefore)

      // swap toward the left (just enough for the tick transition function to trigger)
      // TODO if the input amount is 1 here, the tick transition fires incorrectly!
      // should throw an error or something once the TODOs in pair are fixed
      await pair.swap0For1(2, walletAddress, '0x')
      const tick = await pair.tickCurrent()
      expect(tick).to.be.eq(-1)

      const kAfterSwap = await pair.getLiquidity()
      expect(kAfterSwap.gt(kAfter)).to.be.true
      // TODO not sure this is right
      expect(kAfterSwap).to.be.eq(expandTo18Decimals(3))
    })
  })

  describe('#getFee', () => {
    it('returns fee vote 0 when not initialized', async () => {
      expect(await pair.getFee()).to.eq(FEES[FeeVote.FeeVote0])
    })
    describe('returns only vote when initialized', () => {
      for (const vote of [FeeVote.FeeVote0, FeeVote.FeeVote1, FeeVote.FeeVote4, FeeVote.FeeVote5]) {
        it(`vote: ${FeeVote[vote]}`, async () => {
          await initializeAtZeroTick(vote)
          expect(await pair.getFee()).to.eq(FEES[vote])
        })
      }
    })
    it('median computation', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote0)
      const liquidityVote = await pair.liquidityCurrent(FeeVote.FeeVote0)
      expect(liquidityVote).to.eq(initializeLiquidityAmount)
      expect(await pair.getLiquidity()).to.eq(initializeLiquidityAmount)
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(-1, 1, FeeVote.FeeVote4, initializeLiquidityAmount.add(2))
      expect(await pair.getLiquidity()).to.eq(initializeLiquidityAmount.add(initializeLiquidityAmount.add(2)))
      expect(await pair.getFee()).to.eq(FEES[FeeVote.FeeVote4])
    })
    it('gas cost uninitialized', async () => {
      await snapshotGasCost(pairTest.getGasCostOfGetFee())
    })
    it('gas cost multiple votes median in middle', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote3)
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(-1, 1, FeeVote.FeeVote4, expandTo18Decimals(2))
      await snapshotGasCost(pairTest.getGasCostOfGetFee())
    })
    it('gas cost initialized to vote 5', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote5)
      await snapshotGasCost(pairTest.getGasCostOfGetFee())
    })
  })

  // jankily, these tests are prety interdependent and basically have to be run as a block
  describe('feeTo', () => {
    const liquidityAmount = expandTo18Decimals(1000)

    beforeEach(async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(0)
      await pair.setPosition(MIN_TICK, MAX_TICK, FeeVote.FeeVote0, liquidityAmount)
    })

    it('is initially set to 0', async () => {
      expect(await pair.feeTo()).to.eq(constants.AddressZero)
    })

    it('can be changed by the feeToSetter', async () => {
      await pair.setFeeTo(otherAddress)
      expect(await pair.feeTo()).to.eq(otherAddress)
    })

    it('cannot be changed by addresses that are not feeToSetter', async () => {
      await expect(pair.connect(other).setFeeTo(otherAddress)).to.be.revertedWith(
        'UniswapV3Pair::setFeeTo: caller not feeToSetter'
      )
    })

    const swapAndGetFeeValue = async () => {
      const swapAmount = expandTo18Decimals(1)
      await pair.swap0For1(swapAmount, walletAddress, '0x')

      const {amount0, amount1} = await pair.callStatic.setPosition(MIN_TICK, MAX_TICK, FeeVote.FeeVote0, 0)

      const token0Delta = amount0.mul(-1)
      const token1Delta = amount1.mul(-1)

      return [token0Delta, token1Delta]
    }

    let token0DeltaWithoutFeeTo: BigNumber
    let token1DeltaWithoutFeeTo: BigNumber
    it('off', async () => {
      const [token0Delta, token1Delta] = await swapAndGetFeeValue()

      token0DeltaWithoutFeeTo = token0Delta
      token1DeltaWithoutFeeTo = token1Delta

      // 6 bips * 1e18
      expect(token0Delta).to.eq('599999999999999')
      expect(token1Delta).to.eq(0)
    })

    it('on', async () => {
      await pair.setFeeTo(otherAddress)

      const [token0Delta, token1Delta] = await swapAndGetFeeValue()

      const expectedProtocolDelta0 = token0DeltaWithoutFeeTo.div(6).add(1)
      const expectedProtocolDelta1 = token1DeltaWithoutFeeTo.div(6)

      expect(token0Delta).to.be.eq(token0DeltaWithoutFeeTo.sub(expectedProtocolDelta0))
      expect(token1Delta).to.be.eq(token1DeltaWithoutFeeTo.sub(expectedProtocolDelta1))

      // measure how much the new protocol liquidity is worth
      // off by one (rounded in favor of the user)
      expect(await pair.feeToFees0()).to.eq(expectedProtocolDelta0)
      // off by one (rounded in favor of the smart contract) (?)
      expect(await pair.feeToFees1()).to.eq(expectedProtocolDelta1)
    })

    let token0DeltaTwoSwaps: BigNumber
    let token1DeltaTwoSwaps: BigNumber
    it('off:two swaps', async () => {
      await swapAndGetFeeValue()
      const [token0Delta, token1Delta] = await swapAndGetFeeValue()

      token0DeltaTwoSwaps = token0Delta
      token1DeltaTwoSwaps = token1Delta

      // 6 bips * 2e18
      expect(token0Delta).to.eq('1199999999999999')
      expect(token1Delta).to.eq(0)
    })

    let expectedProtocolDelta0TwoSwaps: BigNumber
    let expectedProtocolDelta1TwoSwaps: BigNumber
    it('on:two swaps', async () => {
      expectedProtocolDelta0TwoSwaps = token0DeltaTwoSwaps.div(6).add(1)
      expectedProtocolDelta1TwoSwaps = token1DeltaTwoSwaps.div(6)

      await pair.setFeeTo(otherAddress)

      await swapAndGetFeeValue()
      const [token0Delta, token1Delta] = await swapAndGetFeeValue()

      expect(token0Delta).to.eq(token0DeltaTwoSwaps.sub(expectedProtocolDelta0TwoSwaps))
      expect(token1Delta).to.eq(token1DeltaTwoSwaps.sub(expectedProtocolDelta1TwoSwaps))

      // measure how much the new protocol liquidity is worth
      // off by two (rounded in favor of the smart contract) (?)
      expect(await pair.feeToFees0()).to.eq(expectedProtocolDelta0TwoSwaps)
      // off by one (rounded in favor of the smart contract) (?)
      expect(await pair.feeToFees1()).to.eq(expectedProtocolDelta1TwoSwaps)
    })

    it('on:two swaps with intermediary withdrawal', async () => {
      await pair.setFeeTo(otherAddress)

      const [realizedGainsToken0, realizedGainsToken1] = await swapAndGetFeeValue()
      await pair.setPosition(MIN_TICK, MAX_TICK, FeeVote.FeeVote0, 0)
      const [token0Delta, token1Delta] = await swapAndGetFeeValue()

      expect(realizedGainsToken0.add(token0Delta)).to.be.lte(token0DeltaTwoSwaps.sub(expectedProtocolDelta0TwoSwaps))
      expect(realizedGainsToken1.add(token1Delta)).to.be.lte(token1DeltaTwoSwaps.sub(expectedProtocolDelta1TwoSwaps))

      // measure how much the new protocol liquidity is worth
      expect(await pair.feeToFees0()).to.be.eq(expectedProtocolDelta0TwoSwaps)
      expect(await pair.feeToFees1()).to.be.eq(expectedProtocolDelta1TwoSwaps)
    })
  })

  describe('#recover', () => {
    beforeEach('initialize the pair', async () => {
      await initializeAtZeroTick(FeeVote.FeeVote0)
    })

    beforeEach('send some token2 to the pair', async () => {
      await token2.transfer(pair.address, 10)
    })

    it('is only callable by feeToSetter', async () => {
      await expect(pair.connect(other).recover(token2.address, otherAddress, 10)).to.be.revertedWith(
        'UniswapV3Pair::recover: caller not feeToSetter'
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
})
