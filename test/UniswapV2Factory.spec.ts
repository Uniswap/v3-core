import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { AddressZero } from 'ethers/constants'
import { bigNumberify } from 'ethers/utils'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'

import { getCreate2Address } from './shared/utilities'
import { factoryFixture } from './shared/fixtures'

import UniswapV2Exchange from '../build/UniswapV2Exchange.json'

chai.use(solidity)

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000'
]

describe('UniswapV2Factory', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader(provider, [wallet, other])

  let factory: Contract
  beforeEach(async () => {
    const fixture = await loadFixture(factoryFixture)
    factory = fixture.factory
  })

  it('feeTo, feeToSetter, allExchanges, allExchangesLength', async () => {
    expect(await factory.feeTo()).to.eq(AddressZero)
    expect(await factory.feeToSetter()).to.eq(wallet.address)
    expect(await factory.allExchangesLength()).to.eq(0)
  })

  async function createExchange(tokens: [string, string]) {
    const bytecode = `0x${UniswapV2Exchange.evm.bytecode.object}`
    const create2Address = getCreate2Address(factory.address, tokens, bytecode)
    await expect(factory.createExchange(...tokens))
      .to.emit(factory, 'ExchangeCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, bigNumberify(1))

    await expect(factory.createExchange(...tokens)).to.be.reverted // UniswapV2: EXCHANGE_EXISTS
    await expect(factory.createExchange(...tokens.slice().reverse())).to.be.reverted // UniswapV2: EXCHANGE_EXISTS
    expect(await factory.getExchange(...tokens)).to.eq(create2Address)
    expect(await factory.getExchange(...tokens.slice().reverse())).to.eq(create2Address)
    expect(await factory.allExchanges(0)).to.eq(create2Address)
    expect(await factory.allExchangesLength()).to.eq(1)

    const exchange = new Contract(create2Address, JSON.stringify(UniswapV2Exchange.abi), provider)
    expect(await exchange.factory()).to.eq(factory.address)
    expect(await exchange.token0()).to.eq(TEST_ADDRESSES[0])
    expect(await exchange.token1()).to.eq(TEST_ADDRESSES[1])
  }

  it('createExchange', async () => {
    await createExchange(TEST_ADDRESSES)
  })

  it('createExchange:reverse', async () => {
    await createExchange(TEST_ADDRESSES.slice().reverse() as [string, string])
  })

  it('createExchange:gas', async () => {
    const gasCost = await factory.estimate.createExchange(...TEST_ADDRESSES)
    console.log(`Gas required for createExchange: ${gasCost}`)
  })

  it('setFeeTo', async () => {
    await expect(factory.connect(other).setFeeTo(other.address)).to.be.reverted // UniswapV2: FORBIDDEN
    await factory.setFeeTo(wallet.address)
    expect(await factory.feeTo()).to.eq(wallet.address)
  })

  it('setFeeToSetter', async () => {
    await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.reverted // UniswapV2: FORBIDDEN
    await factory.setFeeToSetter(other.address)
    expect(await factory.feeToSetter()).to.eq(other.address)
    await expect(factory.setFeeToSetter(wallet.address)).to.be.reverted // UniswapV2: FORBIDDEN
  })
})
