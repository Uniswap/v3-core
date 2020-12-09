import {ethers, waffle} from 'hardhat'
import {UniswapV3Factory} from '../typechain/UniswapV3Factory'
import {expect} from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

import {FeeAmount, getCreate2Address, TICK_SPACINGS} from './shared/utilities'

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

  async function createAndCheckPair(tokens: [string, string], feeAmount: FeeAmount) {
    const create2Address = getCreate2Address(factory.address, tokens, feeAmount, TICK_SPACINGS[feeAmount], pairBytecode)
    const create = factory.createPair(tokens[0], tokens[1], feeAmount)

    await expect(create)
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], feeAmount, TICK_SPACINGS[feeAmount], create2Address, 1)

    await expect(factory.createPair(tokens[0], tokens[1], feeAmount)).to.be.revertedWith(
      'UniswapV3Factory::createPair: pair already exists'
    )
    await expect(factory.createPair(tokens[1], tokens[0], feeAmount)).to.be.revertedWith(
      'UniswapV3Factory::createPair: pair already exists'
    )
    expect(await factory.getPair(tokens[0], tokens[1], feeAmount), 'getPair in order').to.eq(create2Address)
    expect(await factory.getPair(tokens[1], tokens[0], feeAmount), 'getPair in reverse').to.eq(create2Address)
    expect(await factory.allPairs(0), 'first pair in allPairs').to.eq(create2Address)
    expect(await factory.allPairsLength(), 'number of pairs').to.eq(1)

    const pairContractFactory = await ethers.getContractFactory('UniswapV3Pair')
    const pair = pairContractFactory.attach(create2Address)
    expect(await pair.factory(), 'pair factory address').to.eq(factory.address)
    expect(await pair.token0(), 'pair token0').to.eq(TEST_ADDRESSES[0])
    expect(await pair.token1(), 'pair token1').to.eq(TEST_ADDRESSES[1])
    expect(await pair.fee(), 'pair fee').to.eq(feeAmount)
    expect(await pair.tickSpacing(), 'pair tick spacing').to.eq(TICK_SPACINGS[feeAmount])
  }

  describe('#createPair', () => {
    it('succeeds for low fee pair', async () => {
      await createAndCheckPair(TEST_ADDRESSES, FeeAmount.LOW)
    })

    it('succeeds for medium fee pair', async () => {
      await createAndCheckPair(TEST_ADDRESSES, FeeAmount.MEDIUM)
    })

    it('succeeds for high fee pair', async () => {
      await createAndCheckPair(TEST_ADDRESSES, FeeAmount.HIGH)
    })

    it('succeeds if tokens are passed in reverse', async () => {
      await createAndCheckPair([TEST_ADDRESSES[1], TEST_ADDRESSES[0]], FeeAmount.MEDIUM)
    })

    it('gas', async () => {
      await snapshotGasCost(factory.createPair(TEST_ADDRESSES[0], TEST_ADDRESSES[1], FeeAmount.MEDIUM))
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
