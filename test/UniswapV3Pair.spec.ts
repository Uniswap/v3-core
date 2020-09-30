import chai, { expect } from 'chai'
import { createFixtureLoader, deployContract, MockProvider, solidity } from 'ethereum-waffle'
import { BigNumber, constants, Contract } from 'ethers'

import CumulativePriceTest from '../build/CumulativePriceTest.json'
import { pairFixture } from './shared/fixtures'

import {
  bnify2,
  expandTo18Decimals,
  FeeVote,
  getExpectedTick,
  getPositionKey,
  MAX_TICK,
  MIN_TICK,
  mineBlock,
  OVERRIDES,
} from './shared/utilities'

chai.use(solidity)

describe('UniswapV3Pair', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999,
      allowUnlimitedContractSize: true,
    },
  })
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader([wallet], provider)

  let token0: Contract
  let token1: Contract
  let factory: Contract
  let pair: Contract
  beforeEach('load fixture', async () => {
    const fixture = await loadFixture(pairFixture)
    token0 = fixture.token0
    token1 = fixture.token1
    factory = fixture.factory
    pair = fixture.pair
  })

  // this invariant should always hold true.
  afterEach('check tick matches price', async () => {
    // ensure that the tick always matches the price given by virtual reserves
    const reserve0Virtual = await pair.reserve0Virtual()
    const reserve1Virtual = await pair.reserve1Virtual()
    const expectedTick = getExpectedTick(reserve0Virtual, reserve1Virtual)
    const tickCurrent = await pair.tickCurrent()
    expect(tickCurrent).to.eq(expectedTick)
  })

  it('factory, token0, token1', async () => {
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(token0.address)
    expect(await pair.token1()).to.eq(token1.address)
  })

  it('min tick is initialized', async () => {
    const [growthOutside, secondsOutside] = await pair.tickInfos(MIN_TICK)
    expect(growthOutside[0]).to.eq(BigNumber.from(2).pow(112))
    expect(secondsOutside).to.eq(0)
  })

  it('max tick is initialized', async () => {
    const [growthOutside, secondsOutside] = await pair.tickInfos(MAX_TICK)
    expect(growthOutside[0]).to.eq(BigNumber.from(2).pow(112))
    expect(secondsOutside).to.eq(0)
  })

  it('liquidity min', async () => {
    expect(await pair.LIQUIDITY_MIN()).to.eq(1000)
  })

  it('token min', async () => {
    expect(await pair.TOKEN_MIN()).to.eq(101)
  })

  it('fee options', async () => {
    const options = await pair.FEE_OPTIONS()
    expect(options[0]).to.eq(500)
    expect(options[1]).to.eq(1000)
    expect(options[2]).to.eq(3000)
    expect(options[3]).to.eq(6000)
    expect(options[4]).to.eq(10000)
    expect(options[5]).to.eq(20000)
    expect(options.length).to.eq(await pair.NUM_FEE_OPTIONS())
  })

  describe('#initialize', () => {
    it('fails if already initialized', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(expandTo18Decimals(1), expandTo18Decimals(1), 0, FeeVote.FeeVote0, OVERRIDES)
      await expect(
        pair.initialize(expandTo18Decimals(1), expandTo18Decimals(1), 0, FeeVote.FeeVote0, OVERRIDES)
      ).to.be.revertedWith('UniswapV3: ALREADY_INITIALIZED')
    })
    it('fails if amount0 too small', async () => {
      await expect(pair.initialize(100, 101, 1, FeeVote.FeeVote0, OVERRIDES)).to.be.revertedWith(
        'UniswapV3: AMOUNT_0_TOO_SMALL'
      )
    })
    it('fails if amount1 too small', async () => {
      await expect(pair.initialize(101, 100, -1, FeeVote.FeeVote0, OVERRIDES)).to.be.revertedWith(
        'UniswapV3: AMOUNT_1_TOO_SMALL'
      )
    })
    it('fails if amounts are not within tick price bounds', async () => {
      await expect(
        pair.initialize(expandTo18Decimals(1), expandTo18Decimals(1), -1, FeeVote.FeeVote0, OVERRIDES)
      ).to.be.revertedWith('UniswapV3: STARTING_TICK_TOO_SMALL')
      await expect(
        pair.initialize(expandTo18Decimals(1), expandTo18Decimals(1), 1, FeeVote.FeeVote0, OVERRIDES)
      ).to.be.revertedWith('UniswapV3: STARTING_TICK_TOO_LARGE')
    })
    it('fails if liquidity amount is too small', async () => {
      await expect(pair.initialize(500, 500, 0, FeeVote.FeeVote0, OVERRIDES)).to.be.revertedWith(
        'UniswapV3: LIQUIDITY_TOO_SMALL'
      )
    })
    it('fails if cannot transfer from user', async () => {
      await expect(pair.initialize(1000, 1000, 0, FeeVote.FeeVote0, OVERRIDES)).to.be.revertedWith(
        'TransferHelper: TRANSFER_FROM_FAILED'
      )
    })
    it('sets initial variables', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES)
      expect(await pair.reserve0Virtual()).to.eq(2000)
      expect(await pair.reserve1Virtual()).to.eq(1000)
      expect(await pair.blockTimestampLast()).to.not.eq(0)
      expect(await pair.tickCurrent()).to.eq(-70)
      expect(await pair.virtualSupplies(FeeVote.FeeVote1)).to.eq(1414)
    })
    it('creates a position for address 0 for min liquidity', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES)
      const [liquidity, liquidityAdjusted] = await pair.positions(
        getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK, FeeVote.FeeVote1)
      )
      expect(liquidity).to.eq(1000)
      expect(liquidityAdjusted).to.eq(1000)
    })
    it('creates a position for sender address for remaining liquidity', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES)
      const [liquidity, liquidityAdjusted] = await pair.positions(
        getPositionKey(wallet.address, MIN_TICK, MAX_TICK, FeeVote.FeeVote1)
      )
      expect(liquidity).to.eq(414)
      expect(liquidityAdjusted).to.eq(414)
    })
    it('emits an Initialized event with the call arguments', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES))
        .to.emit(pair, 'Initialized')
        .withArgs(2000, 1000, -70, FeeVote.FeeVote1)
    })
    it('emits a PositionSet event with the zero address', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES))
        .to.emit(pair, 'PositionSet')
        .withArgs(constants.AddressZero, MIN_TICK, MAX_TICK, FeeVote.FeeVote1, 1000)
    })
    it('emits a PositionSet event with the sender address for remaining liquidity', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES))
        .to.emit(pair, 'PositionSet')
        .withArgs(wallet.address, MIN_TICK, MAX_TICK, FeeVote.FeeVote1, 414)
    })
    it('transfers the token', async () => {
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await expect(pair.initialize(2000, 1000, -70, FeeVote.FeeVote1, OVERRIDES))
        .to.emit(token0, 'Transfer')
        .withArgs(wallet.address, pair.address, 2000)
        .to.emit(token1, 'Transfer')
        .withArgs(wallet.address, pair.address, 1000)
      expect(await token0.balanceOf(pair.address)).to.eq(2000)
      expect(await token1.balanceOf(pair.address)).to.eq(1000)
    })
  })

  describe('#setPosition', () => {
    it('fails if not initialized', async () => {
      await expect(pair.setPosition(-1, 1, 0, 0)).to.be.revertedWith('UniswapV3: NOT_INITIALIZED')
    })
    describe('after initialization', () => {
      beforeEach('initialize the pair at price of 10:1 with fee vote 1', async () => {
        await token0.approve(pair.address, 10000)
        await token1.approve(pair.address, 1000)
        // 316227 supply minted
        await pair.initialize(10000, 1000, -232, 1, OVERRIDES)
      })

      describe('failure cases', () => {
        it('fails if tickLower less than min tick', async () => {
          await expect(pair.setPosition(-7804, 1, 0, 0)).to.be.revertedWith('UniswapV3: LOWER_TICK')
        })
        it('fails if tickUpper greater than max tick', async () => {
          await expect(pair.setPosition(-1, 7804, 0, 0)).to.be.revertedWith('UniswapV3: UPPER_TICK')
        })
        it('fails if tickLower greater than tickUpper', async () => {
          await expect(pair.setPosition(1, 0, 0, 0)).to.be.revertedWith('UniswapV3: TICKS')
        })
        it('fails if cannot transfer', async () => {
          await expect(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100)).to.be.revertedWith(
            'TransferHelper: TRANSFER_FROM_FAILED'
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
              .withArgs(wallet.address, pair.address, 21558)
            expect(await token0.balanceOf(pair.address)).to.eq(31558)
            expect(await token1.balanceOf(pair.address)).to.eq(1000)
          })
        })

        describe('including current price', () => {
          it('price within range: transfers current price of both tokens', async () => {
            await expect(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100))
              .to.emit(token0, 'Transfer')
              .withArgs(wallet.address, pair.address, 316)
              .to.emit(token1, 'Transfer')
              .withArgs(wallet.address, pair.address, 31)
            expect(await token0.balanceOf(pair.address)).to.eq(10316)
            expect(await token1.balanceOf(pair.address)).to.eq(1031)
          })

          it.skip('initializes tickUpper', async () => {
            await expect(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100))
            const [[growthOutside], secondsOutside] = await pair.tickInfos(MIN_TICK + 1)
            expect(growthOutside).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })

          it.skip('initializes tickLower', async () => {
            await expect(pair.setPosition(MIN_TICK + 1, MAX_TICK - 1, 0, 100))
            const [[growthOutside], secondsOutside] = await pair.tickInfos(MAX_TICK - 1)
            expect(growthOutside).to.eq(0)
            expect(secondsOutside).to.eq(0)
          })
        })

        describe('above current price', () => {
          it('transfers token1 only', async () => {
            await expect(pair.setPosition(-500, -233, 0, 10000))
              .to.emit(token1, 'Transfer')
              .withArgs(wallet.address, pair.address, 2306)
            expect(await token0.balanceOf(pair.address)).to.eq(10000)
            expect(await token1.balanceOf(pair.address)).to.eq(3306)
          })
        })
      })
    })
  })

  const initializeToken0Amount = expandTo18Decimals(2)
  const initializeToken1Amount = expandTo18Decimals(2)
  async function initializeAtZeroTick(tokenAmount: BigNumber, feeVote: FeeVote): Promise<void> {
    await token0.approve(pair.address, tokenAmount)
    await token1.approve(pair.address, tokenAmount)
    await pair.initialize(tokenAmount, tokenAmount, 0, feeVote, OVERRIDES)
  }
  // TODO: Test rest of categories in a loop to reduce code duplication
  describe('post-initialize (fee vote 1 - 0.10%)', () => {
    const fee = FeeVote.FeeVote1

    beforeEach(async () => {
      const tokenAmount = expandTo18Decimals(2)
      await initializeAtZeroTick(tokenAmount, fee)
    })

    describe('with fees', async () => {
      const lowerTick = -1
      const upperTick = 4
      const liquidityDelta = expandTo18Decimals(1000)
      let amount0: BigNumber
      let amount1: BigNumber

      beforeEach(async () => {
        // approve max
        await token0.approve(pair.address, constants.MaxUint256)
        await token1.approve(pair.address, constants.MaxUint256)

        // the LP provides some liquidity in specified tick range
        await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)

        // make a swap so that G grows
        await pair.swap0For1(expandTo18Decimals(2), wallet.address, '0x', OVERRIDES)
        ;[amount0, amount1] = await pair.getLiquidityFee(lowerTick, upperTick, fee)
      })

      // The LP adds more to their previously set position
      it('further adds to the position, compounding with the fees', async () => {
        const liquidityDelta = expandTo18Decimals(1)

        // get the liquidity fee post trade
        await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)

        // this is token0 & token1 balance if the liquidity fee was 0 (we got these
        // values by commenting out the `(amount0, amount1) = getValueAtPrice` line)
        const balance0WithoutFees = BigNumber.from('9976274350446348266538')
        const balance1WithoutFees = BigNumber.from('9995028242330516174969')
        // check that the LP's fees were contributed towards their liquidity provision
        // implicitly, by discounting them on the amount of tokens they need to deposit
        expect(await token0.balanceOf(wallet.address)).to.eq(balance0WithoutFees.add(amount0))
        expect(await token1.balanceOf(wallet.address)).to.eq(balance1WithoutFees.add(amount1))
      })

      it('setPosition with 0 liquidity claims fees', async () => {
        const token0Before = await token0.balanceOf(wallet.address)
        const token1Before = await token1.balanceOf(wallet.address)
        await pair.setPosition(lowerTick, upperTick, fee, 0, OVERRIDES)
        expect(await token0.balanceOf(wallet.address)).to.eq(token0Before.add(amount0))
        expect(await token1.balanceOf(wallet.address)).to.eq(token1Before.add(amount1))
      })
    })

    it('setPosition to the right of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = 2
      const upperTick = 4

      await token0.approve(pair.address, constants.MaxUint256)
      // lower: (990, 1009)
      // upper: (980, 1019)
      const g1 = await pair.getG()
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)
      const g2 = await pair.getG()

      expect(g1[0]).to.eq(g2[0])
      expect(await token0.balanceOf(pair.address)).to.eq(initializeToken0Amount.add(10))
      expect(await token1.balanceOf(pair.address)).to.eq(initializeToken1Amount)
    })

    it('setPosition to the left of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -4
      const upperTick = -2

      await token1.approve(pair.address, constants.MaxUint256)
      // lower: (1020, 980)
      // upper: (1009, 989)
      const g1 = await pair.getG()
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)
      const g2 = await pair.getG()

      expect(g1[0]).to.eq(g2[0])
      expect(await token0.balanceOf(pair.address)).to.eq(initializeToken0Amount)
      expect(await token1.balanceOf(pair.address)).to.eq(initializeToken1Amount.add(9))
    })

    it('setPosition within the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -2
      const upperTick = 2

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      // lower: (1009, 989)
      // upper: (990, 1009)
      const g1 = await pair.getG()
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)
      const g2 = await pair.getG()

      expect(g1[0]).to.eq(g2[0])
      expect(await token0.balanceOf(pair.address)).to.eq(initializeToken0Amount.add(10))
      expect(await token1.balanceOf(pair.address)).to.eq(initializeToken1Amount.add(11))
    })

    it('cannot remove more than the entire position', async () => {
      const lowerTick = -2
      const upperTick = 2
      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, expandTo18Decimals(1000), OVERRIDES)
      await expect(
        pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, expandTo18Decimals(-1001), OVERRIDES)
      ).to.be.revertedWith('ds-math-sub-underflow')
    })

    it('swap0for1', async () => {
      const amount0In = 1000

      const token0BalanceBefore = await token0.balanceOf(wallet.address)
      const token1BalanceBefore = await token1.balanceOf(wallet.address)

      await token0.approve(pair.address, constants.MaxUint256)
      await pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES)

      const token0BalanceAfter = await token0.balanceOf(wallet.address)
      const token1BalanceAfter = await token1.balanceOf(wallet.address)

      expect(token0BalanceBefore.sub(token0BalanceAfter)).to.eq(amount0In)
      expect(token1BalanceAfter.sub(token1BalanceBefore)).to.eq(998)

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-1)
    })

    it('setPosition with 0 liquidityDelta within the current price after swap must collect fees', async () => {
      let liquidityDelta = expandTo18Decimals(100)
      const lowerTick = -2
      const upperTick = 2

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, liquidityDelta, OVERRIDES)

      const amount0In = expandTo18Decimals(1)
      const g0 = await pair.getG()
      await pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES)
      const g1 = await pair.getG()

      expect(g0[0].lt(g1[0])).to.be.true

      const token0BalanceBeforePair = await token0.balanceOf(pair.address)
      const token1BalanceBeforePair = await token1.balanceOf(pair.address)
      const token0BalanceBeforeWallet = await token0.balanceOf(wallet.address)
      const token1BalanceBeforeWallet = await token1.balanceOf(wallet.address)

      const g2 = await pair.getG()
      const reserve0Pre = await pair.reserve0Virtual()
      const reserve1Pre = await pair.reserve1Virtual()
      const virtualSupplyPre = await pair.getVirtualSupply()

      expect(g2[0]).to.be.eq('5192309491953746845268291565863104')
      expect(reserve0Pre).to.be.eq('103000000000000000000')
      expect(reserve1Pre).to.be.eq('101010200273518761200')
      expect(virtualSupplyPre).to.be.eq('102000000000000000000')

      await pair.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, 0, OVERRIDES)

      const g3 = await pair.getG()
      const reserve0Post = await pair.reserve0Virtual()
      const reserve1Post = await pair.reserve1Virtual()
      const virtualSupplyPost = await pair.getVirtualSupply()

      expect(g3[0]).to.be.eq('5192309491953746845251192201729146')
      expect(reserve0Post).to.be.eq('102999754304399858799')
      expect(reserve1Post).to.be.eq('101009959324375299209')
      expect(virtualSupplyPost).to.be.eq('101999756689794034927')

      const [amount0, amount1] = await pair.callStatic.setPosition(lowerTick, upperTick, FeeVote.FeeVote0, 0, OVERRIDES)
      expect(amount0).to.be.eq(0)
      expect(amount1).to.be.eq(0)

      const token0BalanceAfterWallet = await token0.balanceOf(wallet.address)
      const token1BalanceAfterWallet = await token1.balanceOf(wallet.address)
      const token0BalanceAfterPair = await token0.balanceOf(pair.address)
      const token1BalanceAfterPair = await token1.balanceOf(pair.address)

      expect(token0BalanceAfterWallet.gt(token0BalanceBeforeWallet)).to.be.true
      expect(token1BalanceAfterWallet.gt(token1BalanceBeforeWallet)).to.be.true
      expect(token0BalanceAfterPair.lt(token0BalanceBeforePair)).to.be.true
      expect(token1BalanceAfterPair.lt(token1BalanceBeforePair)).to.be.true
    })
  })

  describe('post-initialize (fee vote 2 - 0.30%)', () => {
    const fee = FeeVote.FeeVote2

    beforeEach(async () => {
      const tokenAmount = expandTo18Decimals(2)
      await initializeAtZeroTick(tokenAmount, fee)
    })

    it('swap0for1', async () => {
      const amount0In = 1000

      const token0BalanceBefore = await token0.balanceOf(wallet.address)
      const token1BalanceBefore = await token1.balanceOf(wallet.address)

      await token0.approve(pair.address, constants.MaxUint256)
      await pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES)

      const token0BalanceAfter = await token0.balanceOf(wallet.address)
      const token1BalanceAfter = await token1.balanceOf(wallet.address)

      expect(token0BalanceBefore.sub(token0BalanceAfter)).to.eq(amount0In)
      expect(token1BalanceAfter.sub(token1BalanceBefore)).to.eq(996)

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-1)
    })

    it('swap0for1 to tick -10', async () => {
      const amount0In = expandTo18Decimals(1).div(10)

      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, wallet.address, '094959953735437430')

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-10)
    })

    it('swap0for1 to tick -10 with intermediate liquidity', async () => {
      const amount0In = expandTo18Decimals(1).div(10)

      // add liquidity between -3 and -2 (to the left of the current price)
      const liquidityDelta = expandTo18Decimals(1)
      const lowerTick = -3
      const upperTick = -2
      await token1.approve(pair.address, constants.MaxUint256)
      // lower: (1015037437733209910, 985185336841573394)
      // upper: (1009999999999999995, 990099009900990094)
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)

      await token0.approve(pair.address, constants.MaxUint256)
      await expect(pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES))
        .to.emit(token1, 'Transfer')
        .withArgs(pair.address, wallet.address, '095292372649584247')

      const tickCurrent = await pair.tickCurrent()
      expect(tickCurrent).to.eq(-10)
    })
  })

  describe('Oracle', () => {
    it('`_update` is idempotent', async () => {
      const contract = await deployContract(wallet, CumulativePriceTest, [], OVERRIDES)
      // this call should succeed, the assertions are done inside
      // the contract
      await contract.testUpdateMultipleTransactionsSameBlock(OVERRIDES)
    })

    it('getCumulativePrices', async () => {
      const token0Amount = expandTo18Decimals(3)
      const token1Amount = expandTo18Decimals(3)

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)
      await pair.initialize(token0Amount, token1Amount, 0, FeeVote.FeeVote0, OVERRIDES)

      // make a swap to force the call to `_update`
      await pair.swap0For1(1000, wallet.address, '0x', OVERRIDES)

      // check the price now
      const priceBefore = await pair.getCumulativePrices()

      const blockTimestamp = (await provider.getBlock('latest')).timestamp
      await mineBlock(provider, blockTimestamp + 1000)

      // the cumulative price should be greater as more time elapses
      const priceAfter = await pair.getCumulativePrices()
      expect(bnify2(priceAfter[0]).gt(bnify2(priceBefore[0]))).to.be.true
      expect(bnify2(priceAfter[1]).gt(bnify2(priceBefore[1]))).to.be.true
    })
  })
})
