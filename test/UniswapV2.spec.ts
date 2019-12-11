import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, createFixtureLoader } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { BigNumber, bigNumberify } from 'ethers/utils'

import { expandTo18Decimals } from './shared/utilities'
import { exchangeFixture, ExchangeFixture } from './shared/fixtures'

chai.use(solidity)
const { expect } = chai

describe('UniswapV2', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet] = getWallets(provider)
  const loadFixture = createFixtureLoader(provider, [wallet])

  let token0: Contract
  let token1: Contract
  let exchange: Contract
  beforeEach(async () => {
    const { token0: _token0, token1: _token1, exchange: _exchange }: ExchangeFixture = await loadFixture(
      exchangeFixture as any
    )
    token0 = _token0
    token1 = _token1
    exchange = _exchange
  })

  it('getInputPrice', async () => {
    const testCases: BigNumber[][] = [
      [1, 5, 10],
      [1, 10, 5],

      [2, 5, 10],
      [2, 10, 5],

      [1, 10, 10],
      [1, 100, 100],
      [1, 1000, 1000]
    ].map(a => a.map((n: number) => expandTo18Decimals(n)))

    const expectedOutputs: BigNumber[] = [
      '1662497915624478906',
      '0453305446940074565',

      '2851015155847869602',
      '0831248957812239453',

      '0906610893880149131',
      '0987158034397061298',
      '0996006981039903216'
    ].map((n: string) => bigNumberify(n))

    const outputs = await Promise.all(testCases.map(a => exchange.getInputPrice(...a)))

    expect(outputs).to.deep.eq(expectedOutputs)
  })

  it('mintLiquidity', async () => {
    const token0Amount = expandTo18Decimals(1)
    const token1Amount = expandTo18Decimals(4)
    const expectedLiquidity = expandTo18Decimals(2)

    expect(await exchange.reserve0()).to.eq(bigNumberify(0))
    expect(await exchange.reserve1()).to.eq(bigNumberify(0))

    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)
    await expect(exchange.connect(wallet).mintLiquidity(wallet.address))
      .to.emit(exchange, 'LiquidityMinted')
      .withArgs(
        wallet.address,
        wallet.address,
        token0Amount,
        token1Amount,
        token0Amount,
        token1Amount,
        expectedLiquidity
      )

    expect(await exchange.totalSupply()).to.eq(expectedLiquidity)
    expect(await exchange.balanceOf(wallet.address)).to.eq(expectedLiquidity)

    expect(await exchange.reserve0()).to.eq(token0Amount)
    expect(await exchange.reserve1()).to.eq(token1Amount)
  })

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)
    await exchange.connect(wallet).mintLiquidity(wallet.address)
  }

  // it('swap:gas', async () => {
  //   const token0Amount = expandTo18Decimals(5)
  //   const token1Amount = expandTo18Decimals(10)
  //   await addLiquidity(token0Amount, token1Amount)

  //   const swapAmount = expandTo18Decimals(1)
  //   await token0.transfer(exchange.address, swapAmount)
  //   await exchange.connect(wallet).swap0(wallet.address)

  //   await token0.transfer(exchange.address, swapAmount)
  //   console.log((await exchange.estimate.swap0(wallet.address)).toString())
  // })

  it('swap', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = bigNumberify('1662497915624478906')
    await token0.transfer(exchange.address, swapAmount)
    await expect(exchange.connect(wallet).swap0(wallet.address))
      .to.emit(exchange, 'Swap')
      .withArgs(
        wallet.address,
        wallet.address,
        swapAmount,
        expectedOutputAmount,
        token0Amount.add(swapAmount),
        token1Amount.sub(expectedOutputAmount),
        token0.address
      )

    expect(await token0.balanceOf(exchange.address)).to.eq(token0Amount.add(swapAmount))
    expect(await token1.balanceOf(exchange.address)).to.eq(token1Amount.sub(expectedOutputAmount))

    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0.sub(token0Amount).sub(swapAmount))
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount))
  })

  it('burnLiquidity', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const liquidity = expandTo18Decimals(3)
    await exchange.connect(wallet).transfer(exchange.address, liquidity)
    await expect(exchange.connect(wallet).burnLiquidity(wallet.address))
      .to.emit(exchange, 'LiquidityBurned')
      .withArgs(wallet.address, wallet.address, token0Amount, token1Amount, bigNumberify(0), bigNumberify(0), liquidity)

    expect(await exchange.balanceOf(wallet.address)).to.eq(0)
    expect(await token0.balanceOf(exchange.address)).to.eq(0)
    expect(await token1.balanceOf(exchange.address)).to.eq(0)

    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()

    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0)
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1)
  })
})
