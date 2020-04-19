import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { formatBytes32String } from 'ethers/utils'
import { AddressZero } from 'ethers/constants'

import TokenNamerTest from '../build/TokenNamerTest.json'
import FakeCompliantERC20 from '../build/FakeCompliantERC20.json'
import FakeNoncompliantERC20 from '../build/FakeNoncompliantERC20.json'
import FakeOptionalERC20 from '../build/FakeOptionalERC20.json'

chai.use(solidity)

const overrides = {
  gasLimit: 9999999
}

describe('TokenNamer', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet] = provider.getWallets()

  let tokenNamer: Contract
  before('deploy TokenNamerTest', async () => {
    tokenNamer = await deployContract(wallet, TokenNamerTest, [], overrides)
  })

  function deployCompliant({ name, symbol }: { name: string; symbol: string }): Promise<Contract> {
    return deployContract(wallet, FakeCompliantERC20, [name, symbol], overrides)
  }

  function deployNoncompliant({ name, symbol }: { name: string; symbol: string }): Promise<Contract> {
    return deployContract(
      wallet,
      FakeNoncompliantERC20,
      [formatBytes32String(name), formatBytes32String(symbol)],
      overrides
    )
  }

  function deployOptional(): Promise<Contract> {
    return deployContract(wallet, FakeOptionalERC20, [], overrides)
  }

  async function getName(tokenAddress: string): Promise<string> {
    const tx = await tokenNamer.tokenName(tokenAddress)
    await tx.wait()
    return tokenNamer.name()
  }

  async function getSymbol(tokenAddress: string): Promise<string> {
    const tx = await tokenNamer.tokenSymbol(tokenAddress)
    const receipt = await tx.wait()
    return tokenNamer.symbol()
  }

  it('is deployed', () => {
    expect(tokenNamer.address).to.be.a('string')
  })

  describe('#tokenName', () => {
    it('works with compliant', async () => {
      const token = await deployCompliant({ name: 'token name', symbol: 'tn' })
      expect(await getName(token.address)).to.eq('token name')
    })
    it('works with noncompliant', async () => {
      const token = await deployNoncompliant({ name: 'token name', symbol: 'tn' })
      expect(await getName(token.address)).to.eq('token name')
    })
    it('works with optional', async () => {
      const token = await deployOptional()
      expect(await getName(token.address)).to.eq(token.address.substr(2).toLowerCase())
    })
    it('works with non-code address', async () => {
      const token = await deployOptional()
      expect(await getName(AddressZero)).to.eq(AddressZero.substr(2))
    })
  })

  describe('#tokenSymbol', () => {
    it('works with compliant', async () => {
      const token = await deployCompliant({ name: 'token name', symbol: 'tn' })
      expect(await getSymbol(token.address)).to.eq('tn')
    })
    it('works with noncompliant', async () => {
      const token = await deployNoncompliant({ name: 'token name', symbol: 'tn' })
      expect(await getSymbol(token.address)).to.eq('tn')
    })
    it('works with optional', async () => {
      const token = await deployOptional()
      expect(await getSymbol(token.address)).to.eq(token.address.substr(2, 6).toLowerCase())
    })
    it('works with non-code address', async () => {
      const token = await deployOptional()
      expect(await getSymbol(AddressZero)).to.eq(AddressZero.substr(2, 6))
    })
  })
})
