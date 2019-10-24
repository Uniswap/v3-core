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

    expect(await factory.exchangeCount()).to.eq(0)
  })

  it('can create exchange', async () => {
    const expectedAddress = getAddress(
      `0x${keccak256(
        [
          '0xff',
          factory.address.slice(2),
          keccak256(solidityPack(['address', 'address'], dummyTokens)).slice(2),
          keccak256(bytecode).slice(2)
        ].join('')
      ).slice(-40)}`
    )

    await expect(factory.createExchange(...dummyTokens))
      .to.emit(factory, 'ExchangeCreated')
      .withArgs(...[...dummyTokens, expectedAddress, 0])

    expect(await factory.exchangeCount()).to.eq(1)
    expect(await factory.getTokens(expectedAddress)).to.deep.eq(dummyTokens)
    expect(await factory.getExchange(...dummyTokens)).to.eq(expectedAddress)

    const exchange = new Contract(expectedAddress, UniswapV2.abi, provider)
    expect(await exchange.factory()).to.eq(factory.address)
  })
})
