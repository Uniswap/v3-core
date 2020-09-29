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
  LIQUIDITY_MIN,
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
  })

  describe('#setPosition', () => {
    it('fails if not initialized', async () => {
      await expect(pair.setPosition(-1, 1, 0, 0)).to.be.revertedWith('UniswapV3: NOT_INITIALIZED')
    })
    describe('after initialization', () => {
      beforeEach('initialize the pair at price of 10:1 with fee vote 0', async () => {
        await token0.approve(pair.address, 10000)
        await token1.approve(pair.address, 1000)
        await pair.initialize(10000, 1000, -232, 0, OVERRIDES)
      })
      it('fails if tickLower less than min tick', async () => {
        await expect(pair.setPosition(-7804, 1, 0, 0)).to.be.revertedWith('UniswapV3: LOWER_TICK')
      })
      it('fails if tickUpper greater than max tick', async () => {
        await expect(pair.setPosition(-1, 7804, 0, 0)).to.be.revertedWith('UniswapV3: UPPER_TICK')
      })
      it('fails if tickLower greater than tickUpper', async () => {
        await expect(pair.setPosition(1, 0, 0, 0)).to.be.revertedWith('UniswapV3: TICKS')
      })
      it('initializes tickLower')
      it('initializes tickUpper')
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
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)

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
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)

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
      await pair.setPosition(lowerTick, upperTick, fee, liquidityDelta, OVERRIDES)

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

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(pair.address, token0Amount)
    await token1.transfer(pair.address, token1Amount)
    await pair.mint(wallet.address, OVERRIDES)
  }

  const swapTestCases: BigNumber[][] = [
    [1, 5, 10, '1662497915624478906'],
    [1, 10, 5, '453305446940074565'],

    [2, 5, 10, '2851015155847869602'],
    [2, 10, 5, '831248957812239453'],

    [1, 10, 10, '906610893880149131'],
    [1, 100, 100, '987158034397061298'],
    [1, 1000, 1000, '996006981039903216'],
  ].map((a) => a.map((n) => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))))
  swapTestCases.forEach((swapTestCase, i) => {
    it.skip(`getInputPrice:${i}`, async () => {
      const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, swapAmount)
      await expect(pair.swap(0, expectedOutputAmount.add(1), wallet.address, '0x', OVERRIDES)).to.be.revertedWith(
        'UniswapV3: K'
      )
      await pair.swap(0, expectedOutputAmount, wallet.address, '0x', OVERRIDES)
    })
  })

  const optimisticTestCases: BigNumber[][] = [
    ['997000000000000000', 5, 10, 1], // given amountIn, amountOut = floor(amountIn * .997)
    ['997000000000000000', 10, 5, 1],
    ['997000000000000000', 5, 5, 1],
    [1, 5, 5, '1003009027081243732'], // given amountOut, amountIn = ceiling(amountOut / .997)
  ].map((a) => a.map((n) => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))))
  optimisticTestCases.forEach((optimisticTestCase, i) => {
    it.skip(`optimistic:${i}`, async () => {
      const [outputAmount, token0Amount, token1Amount, inputAmount] = optimisticTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, inputAmount)
      await expect(pair.swap(outputAmount.add(1), 0, wallet.address, '0x', OVERRIDES)).to.be.revertedWith(
        'UniswapV3: K'
      )
      await pair.swap(outputAmount, 0, wallet.address, '0x', OVERRIDES)
    })
  })

  it.skip('swap:token0', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('1662497915624478906')
    await token0.transfer(pair.address, swapAmount)
    await expect(pair.swap(0, expectedOutputAmount, wallet.address, '0x', OVERRIDES))
      .to.emit(token1, 'Transfer')
      .withArgs(pair.address, wallet.address, expectedOutputAmount)
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount.add(swapAmount), token1Amount.sub(expectedOutputAmount))
      .to.emit(pair, 'Swap')
      .withArgs(wallet.address, swapAmount, 0, 0, expectedOutputAmount, wallet.address)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount.add(swapAmount))
    expect(reserves[1]).to.eq(token1Amount.sub(expectedOutputAmount))
    expect(await token0.balanceOf(pair.address)).to.eq(token0Amount.add(swapAmount))
    expect(await token1.balanceOf(pair.address)).to.eq(token1Amount.sub(expectedOutputAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).sub(swapAmount))
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount))
  })

  it.skip('swap:token1', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('453305446940074565')
    await token1.transfer(pair.address, swapAmount)
    await expect(pair.swap(expectedOutputAmount, 0, wallet.address, '0x', OVERRIDES))
      .to.emit(token0, 'Transfer')
      .withArgs(pair.address, wallet.address, expectedOutputAmount)
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount.sub(expectedOutputAmount), token1Amount.add(swapAmount))
      .to.emit(pair, 'Swap')
      .withArgs(wallet.address, 0, swapAmount, expectedOutputAmount, 0, wallet.address)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount.sub(expectedOutputAmount))
    expect(reserves[1]).to.eq(token1Amount.add(swapAmount))
    expect(await token0.balanceOf(pair.address)).to.eq(token0Amount.sub(expectedOutputAmount))
    expect(await token1.balanceOf(pair.address)).to.eq(token1Amount.add(swapAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).add(expectedOutputAmount))
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).sub(swapAmount))
  })

  it.skip('swap:gas', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    // ensure that setting price{0,1}CumulativeLast for the first time doesn't affect our gas math
    await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
    await pair.sync(OVERRIDES)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('453305446940074565')
    await token1.transfer(pair.address, swapAmount)
    await mineBlock(provider, (await provider.getBlock('latest')).timestamp + 1)
    const tx = await pair.swap(expectedOutputAmount, 0, wallet.address, '0x', OVERRIDES)
    const receipt = await tx.wait()
    expect(receipt.gasUsed).to.eq(71770)
  })

  it.skip('burn', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const expectedLiquidity = expandTo18Decimals(3)
    await pair.transfer(pair.address, expectedLiquidity.sub(LIQUIDITY_MIN))
    await expect(pair.burn(wallet.address, OVERRIDES))
      .to.emit(pair, 'Transfer')
      .withArgs(pair.address, constants.AddressZero, expectedLiquidity.sub(LIQUIDITY_MIN))
      .to.emit(token0, 'Transfer')
      .withArgs(pair.address, wallet.address, token0Amount.sub(1000))
      .to.emit(token1, 'Transfer')
      .withArgs(pair.address, wallet.address, token1Amount.sub(1000))
      .to.emit(pair, 'Sync')
      .withArgs(1000, 1000)
      .to.emit(pair, 'Burn')
      .withArgs(wallet.address, token0Amount.sub(1000), token1Amount.sub(1000), wallet.address)

    expect(await pair.balanceOf(wallet.address)).to.eq(0)
    expect(await pair.totalSupply()).to.eq(LIQUIDITY_MIN)
    expect(await token0.balanceOf(pair.address)).to.eq(1000)
    expect(await token1.balanceOf(pair.address)).to.eq(1000)
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(1000))
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(1000))
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

  it.skip('feeTo:off', async () => {
    const token0Amount = expandTo18Decimals(1000)
    const token1Amount = expandTo18Decimals(1000)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('996006981039903216')
    await token1.transfer(pair.address, swapAmount)
    await pair.swap(expectedOutputAmount, 0, wallet.address, '0x', OVERRIDES)

    const expectedLiquidity = expandTo18Decimals(1000)
    await pair.transfer(pair.address, expectedLiquidity.sub(LIQUIDITY_MIN))
    await pair.burn(wallet.address, OVERRIDES)
    expect(await pair.totalSupply()).to.eq(LIQUIDITY_MIN)
  })

  it.skip('feeTo:on', async () => {
    await factory.setFeeTo(other.address)

    const token0Amount = expandTo18Decimals(1000)
    const token1Amount = expandTo18Decimals(1000)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('996006981039903216')
    await token1.transfer(pair.address, swapAmount)
    await pair.swap(expectedOutputAmount, 0, wallet.address, '0x', OVERRIDES)

    const expectedLiquidity = expandTo18Decimals(1000)
    await pair.transfer(pair.address, expectedLiquidity.sub(LIQUIDITY_MIN))
    await pair.burn(wallet.address, OVERRIDES)
    expect(await pair.totalSupply()).to.eq(BigNumber.from('249750499251388').add(LIQUIDITY_MIN))
    expect(await pair.balanceOf(other.address)).to.eq('249750499251388')

    // using 1000 here instead of the symbolic LIQUIDITY_MIN because the amounts only happen to be equal...
    // ...because the initial liquidity amounts were equal
    expect(await token0.balanceOf(pair.address)).to.eq(BigNumber.from(1000).add('249501683697445'))
    expect(await token1.balanceOf(pair.address)).to.eq(BigNumber.from(1000).add('250000187312969'))
  })
})
