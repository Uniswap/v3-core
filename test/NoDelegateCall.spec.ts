import { Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { NoDelegateCallTest } from '../typechain/NoDelegateCallTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

describe('NoDelegateCall', () => {
  let wallet: Wallet, other: Wallet

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>
  before('create fixture loader', async () => {
    ;[wallet, other] = await (ethers as any).getSigners()
    loadFixture = waffle.createFixtureLoader([wallet, other])
  })

  const noDelegateCallFixture = async () => {
    const noDelegateCallTestFactory = await ethers.getContractFactory('NoDelegateCallTest')
    const noDelegateCallTest = (await noDelegateCallTestFactory.deploy()) as NoDelegateCallTest
    const minimalProxyFactory = new ethers.ContractFactory(
      noDelegateCallTestFactory.interface,
      `3d602d80600a3d3981f3363d3d373d3d3d363d73${noDelegateCallTest.address.slice(2)}5af43d82803e903d91602b57fd5bf3`,
      wallet
    )
    const proxy = (await minimalProxyFactory.deploy()) as NoDelegateCallTest
    return { noDelegateCallTest, proxy }
  }

  let base: NoDelegateCallTest
  let proxy: NoDelegateCallTest

  beforeEach('deploy test contracts', async () => {
    ;({ noDelegateCallTest: base, proxy } = await loadFixture(noDelegateCallFixture))
  })

  it('runtime overhead', async () => {
    await snapshotGasCost(
      (await base.getGasCostOfCannotBeDelegateCalled()).sub(await base.getGasCostOfCanBeDelegateCalled())
    )
  })

  it('proxy can call the method without the modifier', async () => {
    await proxy.canBeDelegateCalled()
  })
  it('proxy cannot call the method with the modifier', async () => {
    await expect(proxy.cannotBeDelegateCalled()).to.be.reverted
  })

  it('can call the method that calls into a private method with the modifier', async () => {
    await base.callsIntoNoDelegateCallFunction()
  })
  it('proxy cannot call the method that calls a private method with the modifier', async () => {
    await expect(proxy.callsIntoNoDelegateCallFunction()).to.be.reverted
  })
})
