import { BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import { MockTimeLeChainPool } from '../../typechain/MockTimeLeChainPool'
import { TestLCP20 } from '../../typechain/TestLCP20'
import { LeChainFactory } from '../../typechain/LeChainFactory'
import { TestLeChainCallee } from '../../typechain/TestLeChainCallee'
import { TestLeChainRouter } from '../../typechain/TestLeChainRouter'
import { MockTimeLeChainPoolDeployer } from '../../typechain/MockTimeLeChainPoolDeployer'

import { Fixture } from 'ethereum-waffle'

interface FactoryFixture {
  factory: LeChainFactory
}

async function factoryFixture(): Promise<FactoryFixture> {
  const factoryFactory = await ethers.getContractFactory('LeChainFactory')
  const factory = (await factoryFactory.deploy()) as unknown as LeChainFactory
  return { factory }
}

interface TokensFixture {
  token0: TestLCP20
  token1: TestLCP20
  token2: TestLCP20
}

async function tokensFixture(): Promise<TokensFixture> {
  const tokenFactory = await ethers.getContractFactory('TestLCP20') as unknown as TestLCP20
  const tokenA = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestLCP20
  const tokenB = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestLCP20
  const tokenC = (await tokenFactory.deploy(BigNumber.from(2).pow(255))) as TestLCP20

  const [token0, token1, token2] = [tokenA, tokenB, tokenC].sort((tokenA, tokenB) =>
    tokenA.address.toLowerCase() < tokenB.address.toLowerCase() ? -1 : 1
  )

  return { token0, token1, token2 }
}

type TokensAndFactoryFixture = FactoryFixture & TokensFixture

interface PoolFixture extends TokensAndFactoryFixture {
  swapTargetCallee: TestLeChainCallee
  swapTargetRouter: TestLeChainRouter
  createPool(
    fee: number,
    tickSpacing: number,
    firstToken?: TestLCP20,
    secondToken?: TestLCP20
  ): Promise<MockTimeLeChainPool>
}

// Monday, October 5, 2020 9:00:00 AM GMT-05:00
export const TEST_POOL_START_TIME = 1601906400

export const poolFixture: Fixture<PoolFixture> = async function (): Promise<PoolFixture> {
  const { factory } = await factoryFixture()
  const { token0, token1, token2 } = await tokensFixture()

  const MockTimeLeChainPoolDeployerFactory = await ethers.getContractFactory('MockTimeLeChainPoolDeployer')
  const MockTimeLeChainPoolFactory = await ethers.getContractFactory('MockTimeLeChainPool')

  const calleeContractFactory = await ethers.getContractFactory('TestLeChainCallee')
  const routerContractFactory = await ethers.getContractFactory('TestLeChainRouter')

  const swapTargetCallee = (await calleeContractFactory.deploy()) as unknown as TestLeChainCallee
  const swapTargetRouter = (await routerContractFactory.deploy()) as unknown as TestLeChainRouter

  return {
    token0,
    token1,
    token2,
    factory,
    swapTargetCallee,
    swapTargetRouter,
    createPool: async (fee, tickSpacing, firstToken = token0, secondToken = token1) => {
      const mockTimePoolDeployer = (await MockTimeLeChainPoolDeployerFactory.deploy()) as unknown as MockTimeLeChainPoolDeployer
      const tx = await mockTimePoolDeployer.deploy(
        factory.address,
        firstToken.address,
        secondToken.address,
        fee,
        tickSpacing
      )

      const receipt = await tx.wait()
      const poolAddress = receipt.events?.[0].args?.pool as string
      return MockTimeLeChainPoolFactory.attach(poolAddress) as unknown as MockTimeLeChainPool
    },
  }
}
