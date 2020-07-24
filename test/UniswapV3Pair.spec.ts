import chai, { expect } from 'chai'
import { Contract, constants, BigNumber } from 'ethers'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'

import {
  expandTo18Decimals,
  mineBlock,
  encodePrice,
  OVERRIDES,
  getPositionKey,
  MAX_TICK,
  MIN_TICK,
  LIQUIDITY_MIN
} from './shared/utilities'
import { pairFixture } from './shared/fixtures'

chai.use(solidity)

describe('UniswapV3Pair', () => {
  const provider = new MockProvider({
    ganacheOptions: {
      hardfork: 'istanbul',
      mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
      gasLimit: 9999999,
      allowUnlimitedContractSize: true
    }
  })
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader([wallet], provider)

  let token0: Contract
  let token1: Contract
  let factory: Contract
  let pair: Contract
  beforeEach(async () => {
    const fixture = await loadFixture(pairFixture)
    token0 = fixture.token0
    token1 = fixture.token1
    factory = fixture.factory
    pair = fixture.pair
  })

  it('factory, token0, token1', async () => {
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(token0.address)
    expect(await pair.token1()).to.eq(token1.address)
  })

  const expectedLiquidity = expandTo18Decimals(2)
  const initializeToken0Amount = expandTo18Decimals(2)
  const initializeToken1Amount = expandTo18Decimals(2)
  it('initialize', async () => {
    const expectedUserLiquidity = expectedLiquidity.sub(LIQUIDITY_MIN)
    const expectedTick = 0

    await token0.approve(pair.address, constants.MaxUint256)
    await token1.approve(pair.address, constants.MaxUint256)
    await pair.initialize(initializeToken0Amount, initializeToken1Amount, 0, 0, OVERRIDES)

    expect(await pair.tickCurrent()).to.eq(expectedTick)
    expect(await pair.liquidityVirtual()).to.eq(expectedLiquidity)

    expect(await token0.balanceOf(pair.address)).to.eq(initializeToken0Amount)
    expect(await token1.balanceOf(pair.address)).to.eq(initializeToken1Amount)

    const burntPosition = await pair.positions(getPositionKey(constants.AddressZero, MIN_TICK, MAX_TICK))
    expect(burntPosition.liquidity).to.eq(LIQUIDITY_MIN)
    expect(burntPosition.liquidityScalar).to.eq(LIQUIDITY_MIN)
    expect(burntPosition.feeVote).to.eq(0)

    const position = await pair.positions(getPositionKey(wallet.address, MIN_TICK, MAX_TICK))
    expect(position.liquidity).to.eq(expectedUserLiquidity)
    expect(position.liquidityScalar).to.eq(expectedUserLiquidity)
    expect(position.feeVote).to.eq(0)
  })

  async function initialize(tokenAmount: BigNumber, feeVote = 0): Promise<void> {
    await token0.approve(pair.address, tokenAmount)
    await token1.approve(pair.address, tokenAmount)
    await pair.initialize(tokenAmount, tokenAmount, 0, feeVote, OVERRIDES)
  }
  describe('post-initialize', () => {
    beforeEach(async () => {
      const tokenAmount = expandTo18Decimals(2)
      await initialize(tokenAmount)
    })

    it('setPosition to the right of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = 2
      const upperTick = 4

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      // lower: (990, 1009)
      // upper: (980, 1019)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta, 0, OVERRIDES)

      expect(await token0.balanceOf(pair.address)).to.eq(initializeToken0Amount.add(10))
      expect(await token1.balanceOf(pair.address)).to.eq(initializeToken1Amount)
    })

    it('setPosition to the left of the current price', async () => {
      const liquidityDelta = 1000
      const lowerTick = -4
      const upperTick = -2

      await token0.approve(pair.address, constants.MaxUint256)
      await token1.approve(pair.address, constants.MaxUint256)

      // lower: (1020, 980)
      // upper: (1009, 989)
      await pair.setPosition(lowerTick, upperTick, liquidityDelta, 0, OVERRIDES)

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
      await pair.setPosition(lowerTick, upperTick, liquidityDelta, 0, OVERRIDES)

      expect(await token0.balanceOf(pair.address)).to.eq(initializeToken0Amount.add(10))
      expect(await token1.balanceOf(pair.address)).to.eq(initializeToken1Amount.add(11))
    })
  })

  it('swap0for1 with fee = 0', async () => {
    const tokenAmount = expandTo18Decimals(2)
    await initialize(tokenAmount, 0)

    const amount0In = 1000

    await token0.approve(pair.address, constants.MaxUint256)

    const token0BalanceBefore = await token0.balanceOf(wallet.address)
    const token1BalanceBefore = await token1.balanceOf(wallet.address)

    await pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES)

    const token0BalanceAfter = await token0.balanceOf(wallet.address)
    const token1BalanceAfter = await token1.balanceOf(wallet.address)

    expect(token0BalanceBefore.sub(token0BalanceAfter)).to.eq(amount0In)
    expect(token1BalanceAfter.sub(token1BalanceBefore)).to.eq(999)
  })

  it('swap0for1 with fee = .3%', async () => {
    const tokenAmount = expandTo18Decimals(2)
    await initialize(tokenAmount, 3000)

    const amount0In = 1000

    await token0.approve(pair.address, constants.MaxUint256)

    const token0BalanceBefore = await token0.balanceOf(wallet.address)
    const token1BalanceBefore = await token1.balanceOf(wallet.address)

    await pair.swap0For1(amount0In, wallet.address, '0x', OVERRIDES)

    const token0BalanceAfter = await token0.balanceOf(wallet.address)
    const token1BalanceAfter = await token1.balanceOf(wallet.address)

    expect(token0BalanceBefore.sub(token0BalanceAfter)).to.eq(amount0In)
    expect(token1BalanceAfter.sub(token1BalanceBefore)).to.eq(996)
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
    [1, 1000, 1000, '996006981039903216']
  ].map(a => a.map(n => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))))
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
    [1, 5, 5, '1003009027081243732'] // given amountOut, amountIn = ceiling(amountOut / .997)
  ].map(a => a.map(n => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))))
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

  it.skip('price{0,1}CumulativeLast', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const blockTimestamp = (await pair.getReserves())[2]
    await mineBlock(provider, blockTimestamp + 1)
    await pair.sync(OVERRIDES)

    const initialPrice = encodePrice(token0Amount, token1Amount)
    expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0])
    expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1])
    expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 1)

    const swapAmount = expandTo18Decimals(3)
    await token0.transfer(pair.address, swapAmount)
    await mineBlock(provider, blockTimestamp + 10)
    // swap to a new price eagerly instead of syncing
    await pair.swap(0, expandTo18Decimals(1), wallet.address, '0x', OVERRIDES) // make the price nice

    expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10))
    expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10))
    expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 10)

    await mineBlock(provider, blockTimestamp + 20)
    await pair.sync(OVERRIDES)

    const newPrice = encodePrice(expandTo18Decimals(6), expandTo18Decimals(2))
    expect(await pair.price0CumulativeLast()).to.eq(initialPrice[0].mul(10).add(newPrice[0].mul(10)))
    expect(await pair.price1CumulativeLast()).to.eq(initialPrice[1].mul(10).add(newPrice[1].mul(10)))
    expect((await pair.getReserves())[2]).to.eq(blockTimestamp + 20)
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
