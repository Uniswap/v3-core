import { ethers, waffle, network } from 'hardhat'
import { NoDelegateCallTest } from '../typechain/NoDelegateCallTest'
import { expect } from './shared/expect'
import snapshotGasCost from './shared/snapshotGasCost'

describe('NoDelegateCall', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof waffle.createFixtureLoader>
  before('create fixture loader', async () => {
    loadFixture = waffle.createFixtureLoader([wallet, other])
  })

  const noDelegateCallFixture = async () => {
    const noDelegateCallTestFactory = await ethers.getContractFactory('NoDelegateCallTest')
    const noDelegateCallTest = (await noDelegateCallTestFactory.deploy()) as NoDelegateCallTest

    let proxy: NoDelegateCallTest
    if (network.name === 'optimism') {
      // The EIP-1167 minimal proxy factory cannot be created directly in the OVM because it contains banned opcodes,
      // so the safety checker blocks it. Instead we deploy a proxy that simply forwards calls to the implementation.
      // Useful reference: https://blog.openzeppelin.com/deep-dive-into-the-minimal-proxy-contract/
      const proxyFactory = await ethers.getContractFactory('Proxy') // in reality this is not a minimal proxy
      const deployedProxy = await proxyFactory.deploy(noDelegateCallTest.address)

      // If we try returning and using `deployedProxy`, tests fail with ` TypeError: proxy.<method> is not a function`,
      // so instead we explicitly get an instance with the correct ABI using getContractAt
      proxy = (await ethers.getContractAt('NoDelegateCallTest', deployedProxy.address)) as NoDelegateCallTest
    } else {
      // This is the original implementation
      const minimalProxyFactory = new ethers.ContractFactory(
        noDelegateCallTestFactory.interface,
        `3d602d80600a3d3981f3363d3d373d3d3d363d73${noDelegateCallTest.address.slice(2)}5af43d82803e903d91602b57fd5bf3`,
        wallet
      )
      proxy = (await minimalProxyFactory.deploy()) as NoDelegateCallTest
    }

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
