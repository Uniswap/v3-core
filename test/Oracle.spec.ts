import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, createFixtureLoader, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { BigNumber, bigNumberify } from 'ethers/utils'

import { expandTo18Decimals } from './shared/utilities'
import { exchangeFixture, ExchangeFixture } from './shared/fixtures'

import Oracle from '../build/Oracle.json'

chai.use(solidity)
const { expect } = chai

describe('Oracle', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet] = getWallets(provider)
  const loadFixture = createFixtureLoader(provider, [wallet])

  let token0: Contract
  let token1: Contract
  let exchange: Contract
  let oracle: Contract
  beforeEach(async () => {
    const { token0: _token0, token1: _token1, exchange: _exchange } = (await loadFixture(
      exchangeFixture as any
    )) as ExchangeFixture
    token0 = _token0
    token1 = _token1
    exchange = _exchange
    oracle = await deployContract(wallet, Oracle, [exchange.address])
  })

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(exchange.address, token0Amount)
    await token1.transfer(exchange.address, token1Amount)
    await exchange.connect(wallet).mintLiquidity(wallet.address)
  }

  async function swap(token: Contract, amount: BigNumber) {
    await token.transfer(exchange.address, amount)
    await exchange.connect(wallet).swap(token.address, wallet.address)
  }

  it('exchange, getCurrentPrice', async () => {
    expect(await oracle.exchange()).to.eq(exchange.address)
    expect(await oracle.getCurrentPrice()).to.deep.eq([0, 0].map(n => bigNumberify(n)))
  })

  it('updateCurrentPrice', async () => {
    const token0Amount = expandTo18Decimals(10)
    const token1Amount = expandTo18Decimals(5)

    await addLiquidity(token0Amount, token1Amount)
    await oracle.connect(wallet).initialize()
    await swap(token0, bigNumberify(1))

    await oracle.connect(wallet).updateCurrentPrice()
    expect(await oracle.getCurrentPrice()).to.deep.eq([token0Amount, token1Amount])
  })
})
