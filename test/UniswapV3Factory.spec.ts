import {expect} from './shared/expect'
import {Contract, BigNumber, constants} from 'ethers'
import {waffle} from '@nomiclabs/buidler'
import snapshotGasCost from './shared/snapshotGasCost'

import {getCreate2Address} from './shared/utilities'
import {factoryFixture} from './shared/fixtures'

import UniswapV3Pair from '../build/UniswapV3Pair.json'

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000',
]

describe('UniswapV3Factory', () => {
  const provider = waffle.provider
  const [wallet, other] = provider.getWallets()

  let factory: Contract
  beforeEach(async () => {
    const fixture = await waffle.loadFixture(factoryFixture)
    factory = fixture.factory
  })

  it('feeTo, feeToSetter, allPairsLength', async () => {
    expect(await factory.feeTo()).to.eq(constants.AddressZero)
    expect(await factory.feeToSetter()).to.eq(wallet.address)
    expect(await factory.allPairsLength()).to.eq(0)
  })

  async function createPair(tokens: [string, string]) {
    const create2Address = getCreate2Address(factory.address, tokens, UniswapV3Pair.bytecode)
    await expect(factory.createPair(...tokens))
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, BigNumber.from(1))

    await expect(factory.createPair(...tokens)).to.be.revertedWith('UniswapV3: PAIR_EXISTS')
    await expect(factory.createPair(...tokens.slice().reverse())).to.be.revertedWith('UniswapV3: PAIR_EXISTS')
    expect(await factory.getPair(...tokens)).to.eq(create2Address)
    expect(await factory.getPair(...tokens.slice().reverse())).to.eq(create2Address)
    expect(await factory.allPairs(0)).to.eq(create2Address)
    expect(await factory.allPairsLength()).to.eq(1)

    const pair = new Contract(create2Address, JSON.stringify(UniswapV3Pair.abi), provider)
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(TEST_ADDRESSES[0])
    expect(await pair.token1()).to.eq(TEST_ADDRESSES[1])
  }

  it('createPair', async () => {
    await createPair(TEST_ADDRESSES)
  })

  it('createPair:reverse', async () => {
    await createPair(TEST_ADDRESSES.slice().reverse() as [string, string])
  })

  it('createPair:gas', async () => {
    await snapshotGasCost(factory.createPair(...TEST_ADDRESSES))
  })

  it('setFeeTo', async () => {
    await expect(factory.connect(other).setFeeTo(other.address)).to.be.revertedWith('UniswapV3: FORBIDDEN')
    await factory.setFeeTo(wallet.address)
    expect(await factory.feeTo()).to.eq(wallet.address)
  })

  it('setFeeToSetter', async () => {
    await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.revertedWith('UniswapV3: FORBIDDEN')
    await factory.setFeeToSetter(other.address)
    expect(await factory.feeToSetter()).to.eq(other.address)
    await expect(factory.setFeeToSetter(wallet.address)).to.be.revertedWith('UniswapV3: FORBIDDEN')
  })
})
