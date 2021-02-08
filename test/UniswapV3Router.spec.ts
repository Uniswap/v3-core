import { waffle } from 'hardhat'
import { TestERC20 } from '../typechain/TestERC20'
import { UniswapV3Factory } from '../typechain/UniswapV3Factory'
import { MockTimeUniswapV3Pair } from '../typechain/MockTimeUniswapV3Pair'
import { expect } from './shared/expect'

import { pairFixture } from './shared/fixtures'

import {
  FeeAmount,
  TICK_SPACINGS,
  createPairFunctions,
  PairFunctions,
  createMultiPairFunctions,
  encodePriceSqrt,
  getMinTick,
  getMaxTick,
  expandTo18Decimals,
} from './shared/utilities'
import { TestUniswapV3Router } from '../typechain/TestUniswapV3Router'
import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'

const feeAmount = FeeAmount.MEDIUM
const tickSpacing = TICK_SPACINGS[feeAmount]

const createFixtureLoader = waffle.createFixtureLoader

type ThenArg<T> = T extends PromiseLike<infer U> ? U : T

describe('Test Router Multi-hop', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let token0: TestERC20
  let token1: TestERC20
  let token2: TestERC20
  let token3: TestERC20
  let factory: UniswapV3Factory
  let pair0: MockTimeUniswapV3Pair
  let pair0Reversed: MockTimeUniswapV3Pair
  let pair1: MockTimeUniswapV3Pair
  let pair2: MockTimeUniswapV3Pair
  let pair2Reversed: MockTimeUniswapV3Pair

  let pair0Functions: PairFunctions
  let pair0ReversedFunctions: PairFunctions
  let pair1Functions: PairFunctions
  let pair2Functions: PairFunctions
  let pair2ReversedFunctions: PairFunctions

  let minTick: number
  let maxTick: number

  let swapTargetCallee: TestUniswapV3Callee
  let swapTargetRouter: TestUniswapV3Router

  let loadFixture: ReturnType<typeof createFixtureLoader>
  let createPair: ThenArg<ReturnType<typeof pairFixture>>['createPair']

  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet, other])
  })

  beforeEach('deploy first fixture', async () => {
    ;({ token0, token1, token2, token3, factory, createPair, swapTargetCallee, swapTargetRouter } = await loadFixture(
      pairFixture
    ))

    const createPairWrapped = async (
      amount: number,
      spacing: number,
      firstToken: TestERC20,
      secondToken: TestERC20
    ): Promise<[MockTimeUniswapV3Pair, any]> => {
      const pair = await createPair(amount, spacing, firstToken, secondToken)
      const pairFunctions = createPairFunctions({
        swapTarget: swapTargetCallee,
        token0: firstToken,
        token1: secondToken,
        pair,
      })
      minTick = getMinTick(spacing)
      maxTick = getMaxTick(spacing)
      return [pair, pairFunctions]
    }

    // default to the 30 bips pair
    ;[pair0, pair0Functions] = await createPairWrapped(feeAmount, tickSpacing, token0, token1)
    ;[pair0Reversed, pair0ReversedFunctions] = await createPairWrapped(feeAmount, tickSpacing, token1, token0)
    ;[pair1, pair1Functions] = await createPairWrapped(feeAmount, tickSpacing, token1, token2)
    ;[pair2, pair2Functions] = await createPairWrapped(feeAmount, tickSpacing, token2, token3)
    ;[pair2Reversed, pair2ReversedFunctions] = await createPairWrapped(feeAmount, tickSpacing, token3, token2)
  })

  it('constructor initializes immutables', async () => {
    expect(await pair0.factory()).to.eq(factory.address)
    expect(await pair0.token0()).to.eq(token0.address)
    expect(await pair0.token1()).to.eq(token1.address)
    expect(await pair0Reversed.factory()).to.eq(factory.address)
    expect(await pair0Reversed.token0()).to.eq(token1.address)
    expect(await pair0Reversed.token1()).to.eq(token0.address)

    expect(await pair1.factory()).to.eq(factory.address)
    expect(await pair1.token0()).to.eq(token1.address)
    expect(await pair1.token1()).to.eq(token2.address)

    expect(await pair2.factory()).to.eq(factory.address)
    expect(await pair2.token0()).to.eq(token2.address)
    expect(await pair2.token1()).to.eq(token3.address)
    expect(await pair2Reversed.factory()).to.eq(factory.address)
    expect(await pair2Reversed.token0()).to.eq(token3.address)
    expect(await pair2Reversed.token1()).to.eq(token2.address)
  })

  describe('arbitrary length multi-swaps', () => {
    let inputToken: TestERC20
    let outputToken: TestERC20

    beforeEach('initialize both pairs', async () => {
      inputToken = token0
      outputToken = token3

      await pair0.initialize(encodePriceSqrt(1, 1))
      await pair0Reversed.initialize(encodePriceSqrt(1, 1))

      await pair1.initialize(encodePriceSqrt(1, 1))

      await pair2.initialize(encodePriceSqrt(1, 1))
      await pair2Reversed.initialize(encodePriceSqrt(1, 1))

      await pair0Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
      await pair0ReversedFunctions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))

      await pair1Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))

      await pair2Functions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
      await pair2ReversedFunctions.mint(wallet.address, minTick, maxTick, expandTo18Decimals(1))
    })


    it('Swap 0 for exact 1', async () => {
      
      outputToken = token3

      const { swap0ForExact1Multi } = createMultiPairFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        pairInput: pair0,
        intermediaryPair: pair1,
        pairOutput: pair2,
      })

      const method =  swap0ForExact1Multi

        await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pair2.address, wallet.address, 100)
        .to.emit(token2, 'Transfer')
        .withArgs(pair1.address, pair2.address, 102)
        .to.emit(token1, 'Transfer')
        .withArgs(pair0.address, pair1.address, 104)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pair0.address, 106)
    })
    it('Swap 1 for exact 0', async () => {
      
      outputToken = token3

      const { swap1ForExact0Multi } = createMultiPairFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        pairInput: pair0Reversed,
        intermediaryPair: pair1,
        pairOutput: pair2Reversed,
      })

      const method = swap1ForExact0Multi

        await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pair2Reversed.address, wallet.address, 100)
        .to.emit(token2, 'Transfer')
        .withArgs(pair1.address, pair2Reversed.address, 102)
        .to.emit(token1, 'Transfer')
        .withArgs(pair0Reversed.address, pair1.address, 104)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pair0Reversed.address, 106)
    })
    it('Swap 0 for exact 0', async () => {
      
      outputToken = token3

      const { swap0ForExact0Multi } = createMultiPairFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        pairInput: pair0,
        intermediaryPair: pair1,
        pairOutput: pair2Reversed,
      })

      const method = swap0ForExact0Multi

        await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pair2Reversed.address, wallet.address, 100)
        .to.emit(token2, 'Transfer')
        .withArgs(pair1.address, pair2Reversed.address, 102)
        .to.emit(token1, 'Transfer')
        .withArgs(pair0.address, pair1.address, 104)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pair0.address, 106)
    })
    it('Swap 1 for exact 1', async () => {
      
      outputToken = token3

      const { swap1ForExact1Multi } = createMultiPairFunctions({
        inputToken: token0,
        swapTarget: swapTargetRouter,
        pairInput: pair0Reversed,
        intermediaryPair: pair1,
        pairOutput: pair2,
      })

      const method = swap1ForExact1Multi

        await expect(method(100, wallet.address))
        .to.emit(outputToken, 'Transfer')
        .withArgs(pair2.address, wallet.address, 100)
        .to.emit(token2, 'Transfer')
        .withArgs(pair1.address, pair2.address, 102)
        .to.emit(token1, 'Transfer')
        .withArgs(pair0Reversed.address, pair1.address, 104)
        .to.emit(inputToken, 'Transfer')
        .withArgs(wallet.address, pair0Reversed.address, 106)
    })
  })
})
