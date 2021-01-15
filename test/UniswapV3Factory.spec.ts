import { ethers, waffle } from 'hardhat'
import { UniswapV3Factory } from '../typechain/UniswapV3Factory'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

import { FeeAmount, getCreate2Address, TICK_SPACINGS } from './shared/utilities'

const { constants } = ethers

const TEST_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000',
]

const createFixtureLoader = waffle.createFixtureLoader

describe('UniswapV3Factory', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let factory: UniswapV3Factory
  let pairBytecode: string
  const fixture = async () => {
    const factoryFactory = await ethers.getContractFactory('UniswapV3Factory')
    return (await factoryFactory.deploy()) as UniswapV3Factory
  }

  let loadFixture: ReturnType<typeof createFixtureLoader>
  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet, other])
  })

  before('load pair bytecode', async () => {
    pairBytecode = (await ethers.getContractFactory('UniswapV3Pair')).bytecode
  })

  beforeEach('deploy factory', async () => {
    factory = await loadFixture(fixture)
  })

  it('owner is deployer', async () => {
    expect(await factory.owner()).to.eq(wallet.address)
  })

  it('initial pairs length is 0', async () => {
    expect(await factory.allPairsLength()).to.eq(0)
  })

  it('factory bytecode size', async () => {
    expect(((await waffle.provider.getCode(factory.address)).length - 2) / 2).to.matchSnapshot()
  })

  it('pair bytecode size', async () => {
    await factory.createPair(TEST_ADDRESSES[0], TEST_ADDRESSES[1], FeeAmount.MEDIUM)
    const pairAddress = getCreate2Address(factory.address, TEST_ADDRESSES, FeeAmount.MEDIUM, pairBytecode)
    expect(((await waffle.provider.getCode(pairAddress)).length - 2) / 2).to.matchSnapshot()
  })

  it('initial enabled fee amounts', async () => {
    expect(await factory.allEnabledFeeAmountsLength()).to.eq(3)
    expect(await factory.allEnabledFeeAmounts(0)).to.eq(FeeAmount.LOW)
    expect(await factory.feeAmountTickSpacing(FeeAmount.LOW)).to.eq(TICK_SPACINGS[FeeAmount.LOW])
    expect(await factory.allEnabledFeeAmounts(1)).to.eq(FeeAmount.MEDIUM)
    expect(await factory.feeAmountTickSpacing(FeeAmount.MEDIUM)).to.eq(TICK_SPACINGS[FeeAmount.MEDIUM])
    expect(await factory.allEnabledFeeAmounts(2)).to.eq(FeeAmount.HIGH)
    expect(await factory.feeAmountTickSpacing(FeeAmount.HIGH)).to.eq(TICK_SPACINGS[FeeAmount.HIGH])
  })

  async function createAndCheckPair(
    tokens: [string, string],
    feeAmount: FeeAmount,
    tickSpacing: number = TICK_SPACINGS[feeAmount]
  ) {
    const create2Address = getCreate2Address(factory.address, tokens, feeAmount, pairBytecode)
    const create = factory.createPair(tokens[0], tokens[1], feeAmount)

    await expect(create)
      .to.emit(factory, 'PairCreated')
      .withArgs(TEST_ADDRESSES[0], TEST_ADDRESSES[1], feeAmount, tickSpacing, create2Address, 1)

    await expect(factory.createPair(tokens[0], tokens[1], feeAmount)).to.be.revertedWith('PAE')
    await expect(factory.createPair(tokens[1], tokens[0], feeAmount)).to.be.revertedWith('PAE')
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
    expect(await pair.tickSpacing(), 'pair tick spacing').to.eq(tickSpacing)
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

    it('fails if token a == token b', async () => {
      await expect(factory.createPair(TEST_ADDRESSES[0], TEST_ADDRESSES[0], FeeAmount.LOW)).to.be.revertedWith('A=B')
    })

    it('fails if token a is 0 or token b is 0', async () => {
      await expect(factory.createPair(TEST_ADDRESSES[0], constants.AddressZero, FeeAmount.LOW)).to.be.revertedWith(
        'A=0'
      )
      await expect(factory.createPair(constants.AddressZero, TEST_ADDRESSES[0], FeeAmount.LOW)).to.be.revertedWith(
        'A=0'
      )
      await expect(factory.createPair(constants.AddressZero, constants.AddressZero, FeeAmount.LOW)).to.be.revertedWith(
        'A=B'
      )
    })

    it('fails if fee amount is not enabled', async () => {
      await expect(factory.createPair(TEST_ADDRESSES[0], TEST_ADDRESSES[1], 250)).to.be.revertedWith('FNA')
    })

    it('gas', async () => {
      await snapshotGasCost(factory.createPair(TEST_ADDRESSES[0], TEST_ADDRESSES[1], FeeAmount.MEDIUM))
    })
  })

  describe('#setOwner', () => {
    it('fails if caller is not owner', async () => {
      await expect(factory.connect(other).setOwner(wallet.address)).to.be.revertedWith('OO')
    })

    it('updates owner', async () => {
      await factory.setOwner(other.address)
      expect(await factory.owner()).to.eq(other.address)
    })

    it('emits event', async () => {
      await expect(factory.setOwner(other.address))
        .to.emit(factory, 'OwnerChanged')
        .withArgs(wallet.address, other.address)
    })

    it('cannot be called by original owner', async () => {
      await factory.setOwner(other.address)
      await expect(factory.setOwner(wallet.address)).to.be.revertedWith('OO')
    })
  })

  describe('#enableFeeAmount', () => {
    it('fails if caller is not owner', async () => {
      await expect(factory.connect(other).enableFeeAmount(100, 2)).to.be.revertedWith('OO')
    })
    it('fails if fee is too great', async () => {
      await expect(factory.enableFeeAmount(1000000, 10)).to.be.revertedWith('FEE')
    })
    it('fails if tick spacing is too small', async () => {
      await expect(factory.enableFeeAmount(500, 0)).to.be.revertedWith('TS')
    })
    it('fails if already initialized', async () => {
      await factory.enableFeeAmount(100, 5)
      await expect(factory.enableFeeAmount(100, 10)).to.be.revertedWith('FAI')
    })
    it('sets the fee amount in the mapping', async () => {
      await factory.enableFeeAmount(100, 5)
      expect(await factory.feeAmountTickSpacing(100)).to.eq(5)
    })
    it('appends to the list', async () => {
      expect(await factory.allEnabledFeeAmountsLength()).to.eq(3)
      await factory.enableFeeAmount(100, 5)
      expect(await factory.allEnabledFeeAmountsLength()).to.eq(4)
      expect(await factory.allEnabledFeeAmounts(3)).to.eq(100)
    })
    it('emits an event', async () => {
      await expect(factory.enableFeeAmount(100, 5)).to.emit(factory, 'FeeAmountEnabled').withArgs(100, 5)
    })
    it('enables pair creation', async () => {
      await factory.enableFeeAmount(250, 15)
      await createAndCheckPair([TEST_ADDRESSES[0], TEST_ADDRESSES[1]], 250, 15)
    })
  })
})
