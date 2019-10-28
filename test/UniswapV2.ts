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

const decimalize = (n: number): BigNumber => bigNumberify(n).mul(bigNumberify(10).pow(18))

const token0Details = ['Token 0', 'T0', 18, decimalize(100), chainId]
const token1Details = ['Token 1', 'T1', 18, decimalize(100), chainId]

describe('UniswapV2', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet] = getWallets(provider)
  let token0: Contract
  let token1: Contract
  let factory: Contract
  let exchange: Contract

  beforeEach(async () => {
    token0 = await deployContract(wallet, ERC20, token0Details)
    token1 = await deployContract(wallet, ERC20, token1Details)

    const bytecode = `0x${UniswapV2.evm.bytecode.object}`
    factory = await deployContract(wallet, UniswapV2Factory, [bytecode, chainId], {
      gasLimit: (provider._web3Provider as any).options.gasLimit
    })

    await factory.createExchange(token0.address, token1.address)
    const exchangeAddress = await factory.getExchange(token0.address, token1.address)
    exchange = new Contract(exchangeAddress, UniswapV2.abi, provider)
  })

  it('mintLiquidity', async () => {
    await token0.transfer(exchange.address, decimalize(4))
    await token1.transfer(exchange.address, decimalize(1))
    await expect(exchange.connect(wallet).mintLiquidity(wallet.address))
      .to.emit(exchange, 'LiquidityMinted')
      .withArgs(wallet.address, wallet.address, decimalize(2), decimalize(4), decimalize(1))
  })
})
