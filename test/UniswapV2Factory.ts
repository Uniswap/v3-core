import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { keccak256, solidityPack, getAddress } from 'ethers/utils'

import UniswapV2 from '../build/UniswapV2.json'
import UniswapV2Factory from '../build/UniswapV2Factory.json'

chai.use(solidity)
const { expect } = chai

const dummyTokens = ['0x1000000000000000000000000000000000000000', '0x2000000000000000000000000000000000000000']
const getExpectedAddress = (factoryAddress: string, bytecode: string): string =>
  getAddress(
    `0x${keccak256(
      [
        '0xff',
        factoryAddress.slice(2),
        keccak256(solidityPack(['address', 'address'], dummyTokens)).slice(2),
        keccak256(bytecode).slice(2)
      ].join('')
    ).slice(-40)}`
  )

describe('UniswapV2Factory', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet] = getWallets(provider)
  let bytecode: string
  let factory: Contract

  it('can deploy factory', async () => {
    bytecode = `0x${UniswapV2.evm.bytecode.object}`
    factory = await deployContract(wallet, UniswapV2Factory, [bytecode], {
      gasLimit: (provider._web3Provider as any).options.gasLimit
    })

    expect(await factory.exchangeBytecode()).to.eq(bytecode)
    expect(await factory.exchangeCount()).to.eq(0)
  })

  it('can create exchange', async () => {
    const expectedAddress = getExpectedAddress(factory.address, bytecode)

    await expect(factory.createExchange(...dummyTokens))
      .to.emit(factory, 'ExchangeCreated')
      .withArgs(...[...dummyTokens, expectedAddress, 0])

    expect(await factory.exchangeCount()).to.eq(1)
    expect(await factory.getTokens(expectedAddress)).to.deep.eq(dummyTokens)
    expect(await factory.getExchange(...dummyTokens)).to.eq(expectedAddress)

    const exchange = new Contract(expectedAddress, UniswapV2.abi, provider)
    expect(await exchange.initialized()).to.eq(true)
    expect(await exchange.factory()).to.eq(factory.address)
    expect(await exchange.token0()).to.eq(dummyTokens[0])
    expect(await exchange.token1()).to.eq(dummyTokens[1])
  })
})
