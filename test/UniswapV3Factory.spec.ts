import {expect} from './shared/expect'
import {waffle, ethers} from 'hardhat'
import snapshotGasCost from './shared/snapshotGasCost'
import {UniswapV3Factory} from '../typechain/UniswapV3Factory'

import {getCreate2Address} from './shared/utilities'

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000',
]

describe('UniswapV3Factory', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let factory: UniswapV3Factory
  let pairBytecode: string
  beforeEach('deploy factory', async () => {
    const factoryFactory = await ethers.getContractFactory('UniswapV3Factory')
    pairBytecode = (await ethers.getContractFactory('UniswapV3Pair')).bytecode
    factory = (await factoryFactory.deploy(await wallet.getAddress())) as UniswapV3Factory
  })

  it('initial feeToSetter is deployer', async () => {
    expect(await factory.feeToSetter()).to.eq(wallet.address)
  })

  it('initial pairs length is 0', async () => {
    expect(await factory.allPairsLength()).to.eq(0)
  })

  async function createPair(tokens: [string, string]) {
    const reverseTokens: [string, string] = [tokens[1], tokens[0]]

    const create2Address = getCreate2Address(factory.address, tokens, pairBytecode)
    await expect(factory.createPair(...tokens))
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], create2Address, 1)

    await expect(factory.createPair(...tokens)).to.be.revertedWith('UniswapV3::createPair: pair already exists')
    await expect(factory.createPair(...reverseTokens)).to.be.revertedWith('UniswapV3::createPair: pair already exists')
    expect(await factory.getPair(...tokens)).to.eq(create2Address)
    expect(await factory.getPair(...reverseTokens)).to.eq(create2Address)
    expect(await factory.allPairs(0)).to.eq(create2Address)
    expect(await factory.allPairsLength()).to.eq(1)

    const pairContractFactory = await ethers.getContractFactory('UniswapV3Pair')
    const pair = pairContractFactory.attach(create2Address)
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(TEST_ADDRESSES[0])
    expect(await pair.token1()).to.eq(TEST_ADDRESSES[1])
  }

  describe('#createPair', () => {
    it('succeeds', async () => {
      await createPair(TEST_ADDRESSES)
    })

    it('succeeds in reverse', async () => {
      await createPair([TEST_ADDRESSES[1], TEST_ADDRESSES[0]])
    })

    it('gas', async () => {
      await snapshotGasCost(factory.createPair(...TEST_ADDRESSES))
    })
  })

  describe('#setFeeToSetter', () => {
    it('fails if caller is not feeToSetter', async () => {
      await expect(factory.connect(other).setFeeToSetter(wallet.address)).to.be.revertedWith(
        'UniswapV3::setFeeToSetter: must be called by feeToSetter'
      )
    })

    it('updates feeToSetter', async () => {
      await factory.setFeeToSetter(other.address)
      expect(await factory.feeToSetter()).to.eq(other.address)
    })

    it('cannot be called by original feeToSetter', async () => {
      await factory.setFeeToSetter(other.address)
      await expect(factory.setFeeToSetter(wallet.address)).to.be.revertedWith(
        'UniswapV3::setFeeToSetter: must be called by feeToSetter'
      )
    })
  })
})
