import chai from 'chai'
import { solidity, MockProvider, createFixtureLoader } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { bigNumberify } from 'ethers/utils'

import { getCreate2Address } from './shared/utilities'
import { factoryFixture, FactoryFixture } from './shared/fixtures'

import UniswapV2Exchange from '../build/UniswapV2Exchange.json'
import { AddressZero } from 'ethers/constants'

chai.use(solidity)
const { expect } = chai

const TEST_ADDRESSES = {
  token0: '0x1000000000000000000000000000000000000000',
  token1: '0x2000000000000000000000000000000000000000'
}

describe('UniswapV2Factory', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader(provider, [wallet])

  let factory: Contract
  beforeEach(async () => {
    const { factory: _factory }: FactoryFixture = await loadFixture(factoryFixture as any)
    factory = _factory
  })

  it('feeToSetter, feeTo, exchangesCount', async () => {
    expect(await factory.feeToSetter()).to.eq(wallet.address)
    expect(await factory.feeTo()).to.eq(AddressZero)
    expect(await factory.exchangesCount()).to.eq(0)
  })

  it('sortTokens', async () => {
    expect(await factory.sortTokens(TEST_ADDRESSES.token0, TEST_ADDRESSES.token1)).to.deep.eq([
      TEST_ADDRESSES.token0,
      TEST_ADDRESSES.token1
    ])
    expect(await factory.sortTokens(TEST_ADDRESSES.token1, TEST_ADDRESSES.token0)).to.deep.eq([
      TEST_ADDRESSES.token0,
      TEST_ADDRESSES.token1
    ])
  })

  async function createExchange(tokens: string[]) {
    const bytecode = `0x${UniswapV2Exchange.evm.bytecode.object}`
    const create2Address = getCreate2Address(factory.address, TEST_ADDRESSES.token0, TEST_ADDRESSES.token1, bytecode)
    await expect(factory.createExchange(...tokens))
      .to.emit(factory, 'ExchangeCreated')
      .withArgs(TEST_ADDRESSES.token0, TEST_ADDRESSES.token1, create2Address, bigNumberify(1))

    await expect(factory.createExchange(...tokens)).to.be.reverted // UniswapV2Factory: EXCHANGE_EXISTS
    await expect(factory.createExchange(...tokens.slice().reverse())).to.be.reverted // UniswapV2Factory: EXCHANGE_EXISTS
    expect(await factory.getExchange(...tokens)).to.eq(create2Address)
    expect(await factory.getExchange(...tokens.slice().reverse())).to.eq(create2Address)
    expect(await factory.exchanges(0)).to.eq(create2Address)
    expect(await factory.exchangesCount()).to.eq(1)

    const exchange = new Contract(create2Address, JSON.stringify(UniswapV2Exchange.abi), provider)
    expect(await exchange.factory()).to.eq(factory.address)
    expect(await exchange.token0()).to.eq(TEST_ADDRESSES.token0)
    expect(await exchange.token1()).to.eq(TEST_ADDRESSES.token1)
  }

  it('createExchange', async () => {
    await createExchange([TEST_ADDRESSES.token0, TEST_ADDRESSES.token1])
  })

  it('createExchange:reverse', async () => {
    await createExchange([TEST_ADDRESSES.token1, TEST_ADDRESSES.token0])
  })

  it('createExchange:gas', async () => {
    const gasCost = await factory.estimate.createExchange(TEST_ADDRESSES.token0, TEST_ADDRESSES.token1)
    console.log(`Gas required for createExchange: ${gasCost}`)
  })

  it('setFeeToSetter', async () => {
    await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.reverted // UniswapV2Factory: FORBIDDEN
    await factory.setFeeToSetter(other.address)
    expect(await factory.feeToSetter()).to.eq(other.address)
    await expect(factory.setFeeToSetter(wallet.address)).to.be.reverted // UniswapV2Factory: FORBIDDEN
  })

  it('setFeeTo', async () => {
    await expect(factory.connect(other).setFeeTo(other.address)).to.be.reverted // UniswapV2Factory: FORBIDDEN
    await factory.setFeeTo(wallet.address)
    expect(await factory.feeTo()).to.eq(wallet.address)
  })
})
