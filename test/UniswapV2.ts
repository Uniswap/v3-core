import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { BigNumber, bigNumberify } from 'ethers/utils'

import ERC20 from '../build/GenericERC20.json'
import UniswapV2 from '../build/UniswapV2.json'
import UniswapV2Factory from '../build/UniswapV2Factory.json'

chai.use(solidity)
const { expect } = chai

const chainId = 1

const decimalize = (n: number | string): BigNumber => bigNumberify(n).mul(bigNumberify(10).pow(18))

const tokenADetails = ['Mock Token A', 'MOCKA', 18, decimalize(100), chainId]
const tokenBDetails = ['Mock Token B', 'MOCKB', 18, decimalize(100), chainId]

describe('UniswapV2', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet] = getWallets(provider)
  let token0: Contract
  let token1: Contract
  let factory: Contract
  let exchange: Contract

  beforeEach(async () => {
    const tokenA = await deployContract(wallet, ERC20, tokenADetails)
    const tokenB = await deployContract(wallet, ERC20, tokenBDetails)

    token0 = tokenA.address < tokenB.address ? tokenA : tokenB
    token1 = tokenA.address < tokenB.address ? tokenB : tokenA

    const bytecode = `0x${UniswapV2.evm.bytecode.object}`
    factory = await deployContract(wallet, UniswapV2Factory, [bytecode, chainId], {
      gasLimit: (provider._web3Provider as any).options.gasLimit
    })

    await factory.createExchange(token0.address, token1.address)
    const exchangeAddress = await factory.getExchange(token0.address, token1.address)
    exchange = new Contract(exchangeAddress, UniswapV2.abi, provider)
  })

  it('initialize:fail', async () => {
    await expect(exchange.connect(wallet).initialize(token0.address, token1.address, chainId)).to.be.revertedWith(
      'UniswapV2: ALREADY_INITIALIZED'
    )
  })

  it('getAmountOutput', async () => {
    const testCases: BigNumber[][] = [
      ['1', '005', '010'].map((n: string) => decimalize(n)),
      ['1', '010', '005'].map((n: string) => decimalize(n)),

      ['2', '005', '010'].map((n: string) => decimalize(n)),
      ['2', '010', '005'].map((n: string) => decimalize(n)),

      ['1', '010', '010'].map((n: string) => decimalize(n)),
      ['1', '100', '100'].map((n: string) => decimalize(n))
    ]

    const expectedOutputs: BigNumber[] = [
      '1662497915624478906',
      '0453305446940074565',

      '2851015155847869602',
      '0831248957812239453',

      '0906610893880149131',
      '0987158034397061298'
    ].map((n: string) => bigNumberify(n))

    const outputs = await Promise.all(testCases.map(c => exchange.getAmountOutput(...c)))
    expect(outputs).to.deep.eq(expectedOutputs)
  })

  it('mintLiquidity', async () => {
    const token0Amount = decimalize(1)
    const token1Amount = decimalize(4)
    const expectedLiquidity = decimalize(2)

    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)
    await expect(exchange.connect(wallet).mintLiquidity(wallet.address))
      .to.emit(exchange, 'LiquidityMinted')
      .withArgs(wallet.address, wallet.address, expectedLiquidity, token0Amount, token1Amount)

    expect(await exchange.totalSupply()).to.eq(expectedLiquidity)
    expect(await exchange.balanceOf(wallet.address)).to.eq(expectedLiquidity)
  })

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)
    await exchange.connect(wallet).mintLiquidity(wallet.address)
  }

  it('swap', async () => {
    const token0Amount = decimalize(5)
    const token1Amount = decimalize(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = decimalize(1)
    const expectedOutputAmount = bigNumberify('1662497915624478906')

    await token0.transfer(exchange.address, swapAmount)
    await expect(exchange.connect(wallet).swap(token0.address, wallet.address))
      .to.emit(exchange, 'Swap')
      .withArgs(token0.address, wallet.address, wallet.address, swapAmount, expectedOutputAmount)

    expect(await token0.balanceOf(exchange.address)).to.eq(token0Amount.add(swapAmount))
    expect(await token1.balanceOf(exchange.address)).to.eq(token1Amount.sub(expectedOutputAmount))

    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount))
  })

  it('burnLiquidity', async () => {
    const token0Amount = decimalize(3)
    const token1Amount = decimalize(3)
    await addLiquidity(token0Amount, token1Amount)
    const liquidity = decimalize(3)

    await exchange.connect(wallet).transfer(exchange.address, liquidity)
    await expect(exchange.connect(wallet).burnLiquidity(liquidity, wallet.address))
      .to.emit(exchange, 'LiquidityBurned')
      .withArgs(wallet.address, wallet.address, liquidity, token0Amount, token1Amount)

    expect(await exchange.balanceOf(wallet.address)).to.eq(0)
    expect(await token0.balanceOf(exchange.address)).to.eq(0)
    expect(await token1.balanceOf(exchange.address)).to.eq(0)

    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()

    expect(await token0.balanceOf(wallet.address)).to.eq(totalSupplyToken0)
    expect(await token1.balanceOf(wallet.address)).to.eq(totalSupplyToken1)
  })

  it('getReserves', async () => {
    const token0Amount = decimalize(3)
    const token1Amount = decimalize(3)

    expect(await exchange.getReserves()).to.deep.eq([0, 0].map(n => bigNumberify(n)))
    await addLiquidity(token0Amount, token1Amount)
    expect(await exchange.getReserves()).to.deep.eq([token0Amount, token1Amount])
  })

  it('getData', async () => {
    const token0Amount = decimalize(3)
    const token1Amount = decimalize(3)

    const preData = await exchange.getData()
    expect(preData).to.deep.eq([0, 0, 0, 0].map(n => bigNumberify(n)))

    await addLiquidity(token0Amount, token1Amount)

    const data = await exchange.getData()
    expect(data).to.deep.eq([0, 0].map(n => bigNumberify(n)).concat(data.slice(2, 4)))

    const dummySwapAmount = bigNumberify(1)
    await token0.transfer(exchange.address, dummySwapAmount)
    await exchange.connect(wallet).swap(token0.address, wallet.address)

    const postData = await exchange.getData()
    expect(postData).to.deep.eq([
      token0Amount.mul(bigNumberify(2)),
      token1Amount.mul(bigNumberify(2)),
      data[2].add(bigNumberify(2)),
      postData[3]
    ])
  })
})
