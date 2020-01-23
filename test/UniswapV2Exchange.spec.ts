import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'
import { BigNumber, bigNumberify } from 'ethers/utils'

import { expandTo18Decimals, mineBlock } from './shared/utilities'
import { exchangeFixture } from './shared/fixtures'
import { AddressZero } from 'ethers/constants'

chai.use(solidity)

const overrides = {
  gasLimit: 1000000
}

describe('UniswapV2Exchange', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet] = provider.getWallets()
  const loadFixture = createFixtureLoader(provider, [wallet])

  let token0: Contract
  let token1: Contract
  let exchange: Contract
  beforeEach(async () => {
    const fixture = await loadFixture(exchangeFixture)
    token0 = fixture.token0
    token1 = fixture.token1
    exchange = fixture.exchange
  })

  it('mint', async () => {
    const token0Amount = expandTo18Decimals(1)
    const token1Amount = expandTo18Decimals(4)
    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)

    const expectedLiquidity = expandTo18Decimals(2)
    await expect(exchange.mint(wallet.address, overrides))
      .to.emit(exchange, 'Transfer')
      .withArgs(AddressZero, wallet.address, expectedLiquidity)
      .to.emit(exchange, 'Sync')
      .withArgs(token0Amount, token1Amount)
      .to.emit(exchange, 'Mint')
      .withArgs(wallet.address, token0Amount, token1Amount)

    expect(await exchange.totalSupply()).to.eq(expectedLiquidity)
    expect(await exchange.balanceOf(wallet.address)).to.eq(expectedLiquidity)
    expect(await token0.balanceOf(exchange.address)).to.eq(token0Amount)
    expect(await token1.balanceOf(exchange.address)).to.eq(token1Amount)
    const reserves = await exchange.getReserves()
    expect(reserves[0]).to.eq(token0Amount)
    expect(reserves[1]).to.eq(token1Amount)
  })

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)
    await exchange.mint(wallet.address, overrides)
  }

  it('getInputPrice', async () => {
    const testCases: BigNumber[][] = [
      [1, 5, 10, '1662497915624478906'],
      [1, 10, 5, '453305446940074565'],

      [2, 5, 10, '2851015155847869602'],
      [2, 10, 5, '831248957812239453'],

      [1, 10, 10, '906610893880149131'],
      [1, 100, 100, '987158034397061298'],
      [1, 1000, 1000, '996006981039903216']
    ].map(a => a.map((n, i) => (i === 3 ? bigNumberify(n) : expandTo18Decimals(n as number))))

    for (let testCase of testCases) {
      await addLiquidity(testCase[1], testCase[2])
      await token0.transfer(exchange.address, testCase[0])
      await expect(exchange.swap(token0.address, testCase[3].add(1), wallet.address, overrides)).to.be.reverted // UniswapV2: K_VIOLATED
      await exchange.swap(token0.address, testCase[3], wallet.address, overrides)
      const totalSupply = await exchange.totalSupply()
      await exchange.transfer(exchange.address, totalSupply)
      await exchange.burn(wallet.address, overrides)
    }
  })

  it('swap:0', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = bigNumberify('1662497915624478906')
    await token0.transfer(exchange.address, swapAmount)
    await expect(exchange.swap(token0.address, expectedOutputAmount, wallet.address, overrides))
      .to.emit(exchange, 'Sync')
      .withArgs(token0Amount.add(swapAmount), token1Amount.sub(expectedOutputAmount))
      .to.emit(exchange, 'Swap')
      .withArgs(wallet.address, token0.address, swapAmount, expectedOutputAmount, wallet.address)

    const reserves = await exchange.getReserves()
    expect(reserves[0]).to.eq(token0Amount.add(swapAmount))
    expect(reserves[1]).to.eq(token1Amount.sub(expectedOutputAmount))
    expect(await token0.balanceOf(exchange.address)).to.eq(token0Amount.add(swapAmount))
    expect(await token1.balanceOf(exchange.address)).to.eq(token1Amount.sub(expectedOutputAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).sub(swapAmount))
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount))
  })

  it('swap:1', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = bigNumberify('453305446940074565')
    await token1.transfer(exchange.address, swapAmount)
    await expect(exchange.swap(token1.address, expectedOutputAmount, wallet.address, overrides))
      .to.emit(exchange, 'Sync')
      .withArgs(token0Amount.sub(expectedOutputAmount), token1Amount.add(swapAmount))
      .to.emit(exchange, 'Swap')
      .withArgs(wallet.address, token1.address, swapAmount, expectedOutputAmount, wallet.address)

    const reserves = await exchange.getReserves()
    expect(reserves[0]).to.eq(token0Amount.sub(expectedOutputAmount))
    expect(reserves[1]).to.eq(token1Amount.add(swapAmount))
    expect(await token0.balanceOf(exchange.address)).to.eq(token0Amount.sub(expectedOutputAmount))
    expect(await token1.balanceOf(exchange.address)).to.eq(token1Amount.add(swapAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).add(expectedOutputAmount))
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).sub(swapAmount))
  })

  it('swap:gas', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    // ensure that setting price{0,1}CumulativeLast for the first time doesn't affect our gas math
    await mineBlock(provider, 1)
    await exchange.sync(overrides)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = bigNumberify('453305446940074565')
    await token0.transfer(exchange.address, swapAmount)
    await mineBlock(provider, 1)
    const gasCost = await exchange.estimate.swap(token0.address, expectedOutputAmount, wallet.address, overrides)
    console.log(`Gas required for swap: ${gasCost}`)
  })

  it('burn', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const expectedLiquidity = expandTo18Decimals(3)
    await exchange.transfer(exchange.address, expectedLiquidity)
    // this test is bugged, it catches the token{0,1} transfers before the lp transfers
    await expect(exchange.burn(wallet.address, overrides))
      // .to.emit(exchange, 'Transfer')
      // .withArgs(exchange.address, AddressZero, expectedLiquidity)
      .to.emit(exchange, 'Burn')
      .withArgs(wallet.address, token0Amount, token1Amount, wallet.address)
      .to.emit(exchange, 'Sync')
      .withArgs(0, 0)

    expect(await exchange.balanceOf(wallet.address)).to.eq(0)
    expect(await exchange.totalSupply()).to.eq(0)
    expect(await token0.balanceOf(exchange.address)).to.eq(0)
    expect(await token1.balanceOf(exchange.address)).to.eq(0)
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0)
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1)
  })

  it('price{0,1}CumulativeLast', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const blockTimestamp = (await exchange.getReserves())[2]
    expect(await exchange.price0CumulativeLast()).to.eq(0)
    expect(await exchange.price1CumulativeLast()).to.eq(0)

    await mineBlock(provider, 1)
    await exchange.sync(overrides)
    expect(await exchange.price0CumulativeLast()).to.eq(bigNumberify(2).pow(112))
    expect(await exchange.price1CumulativeLast()).to.eq(bigNumberify(2).pow(112))
    expect((await exchange.getReserves())[2]).to.eq(blockTimestamp + 1)

    await mineBlock(provider, 9)
    await exchange.sync(overrides)
    expect(await exchange.price0CumulativeLast()).to.eq(
      bigNumberify(2)
        .pow(112)
        .mul(10)
    )
    expect(await exchange.price1CumulativeLast()).to.eq(
      bigNumberify(2)
        .pow(112)
        .mul(10)
    )
    expect((await exchange.getReserves())[2]).to.eq(blockTimestamp + 10)
  })
})
