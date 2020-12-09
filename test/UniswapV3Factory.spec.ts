import {ethers, waffle} from 'hardhat'
import {UniswapV3Factory} from '../typechain/UniswapV3Factory'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

import {FEES, FeeOption, getCreate2Address} from './shared/utilities'

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

  it('initial owner is deployer', async () => {
    expect(await factory.owner()).to.eq(wallet.address)
  })

  it('initial pairs length is 0', async () => {
    expect(await factory.allPairsLength()).to.eq(0)
  })

  async function createPair(tokens: [string, string], feeOption: FeeOption) {
    const create2Address = getCreate2Address(factory.address, tokens, FEES[feeOption], pairBytecode)
    const create = factory.createPair(tokens[0], tokens[1], FEES[feeOption])

    await expect(create)
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], FEES[feeOption], create2Address, 1)

    await expect(factory.createPair(tokens[0], tokens[1], FEES[feeOption])).to.be.revertedWith(
      'UniswapV3Factory::createPair: pair already exists'
    )
    await expect(factory.createPair(tokens[1], tokens[0], FEES[feeOption])).to.be.revertedWith(
      'UniswapV3Factory::createPair: pair already exists'
    )
    expect(await factory.getPair(tokens[0], tokens[1], FEES[feeOption]), 'getPair in order').to.eq(create2Address)
    expect(await factory.getPair(tokens[1], tokens[0], FEES[feeOption]), 'getPair in reverse').to.eq(create2Address)
    expect(await factory.allPairs(0), 'first pair in allPairs').to.eq(create2Address)
    expect(await factory.allPairsLength(), 'number of pairs').to.eq(1)

    const pairContractFactory = await ethers.getContractFactory('UniswapV3Pair')
    const pair = pairContractFactory.attach(create2Address)
    expect(await pair.factory(), 'pair factory address').to.eq(factory.address)
    expect(await pair.token0(), 'pair token0').to.eq(TEST_ADDRESSES[0])
    expect(await pair.token1(), 'pair token1').to.eq(TEST_ADDRESSES[1])
    expect(await pair.fee(), 'pair fee').to.eq(FEES[feeOption])
  }

  describe('#createPair', () => {
    it('succeeds', async () => {
      await createPair(TEST_ADDRESSES, FeeOption.FeeOption3)
    })

    it('succeeds in reverse', async () => {
      await createPair([TEST_ADDRESSES[1], TEST_ADDRESSES[0]], FeeOption.FeeOption1)
    })

    it('gas', async () => {
      await snapshotGasCost(factory.createPair(TEST_ADDRESSES[0], TEST_ADDRESSES[1], FEES[FeeOption.FeeOption0]))
    })
  })

  describe('#setOwner', () => {
    it('fails if caller is not owner', async () => {
      await expect(factory.connect(other).setOwner(wallet.address)).to.be.revertedWith(
        'UniswapV3Factory::setOwner: must be called by owner'
      )
    })

    it('updates owner', async () => {
      await factory.setOwner(other.address)
      expect(await factory.owner()).to.eq(other.address)
    })

    it('cannot be called by original owner', async () => {
      await factory.setOwner(other.address)
      await expect(factory.setOwner(wallet.address)).to.be.revertedWith(
        'UniswapV3Factory::setOwner: must be called by owner'
      )
    })
  })
})
