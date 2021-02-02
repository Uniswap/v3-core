import { Decimal } from 'decimal.js'
import { BigNumber, BigNumberish, ContractTransaction } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { MockTimeUniswapV3Pair } from '../typechain/MockTimeUniswapV3Pair'
import { TestERC20 } from '../typechain/TestERC20'
import { expect } from './shared/expect'
import { pairFixture } from './shared/fixtures'

import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'

import {
  createPairFunctions,
  encodePriceSqrt,
  expandTo18Decimals,
  FeeAmount,
  getMaxLiquidityPerTick,
  getMaxTick,
  getMinTick,
  MaxUint128,
  TICK_SPACINGS,
} from './shared/utilities'

const createFixtureLoader = waffle.createFixtureLoader
const { constants } = ethers

interface BaseSwapTestCase {
  zeroForOne: boolean
  sqrtPriceLimit?: BigNumber
}
interface SwapExact0For1TestCase extends BaseSwapTestCase {
  zeroForOne: true
  exactOut: false
  amount0: BigNumberish
  sqrtPriceLimit?: BigNumber
}
interface SwapExact1For0TestCase extends BaseSwapTestCase {
  zeroForOne: false
  exactOut: false
  amount1: BigNumberish
  sqrtPriceLimit?: BigNumber
}
interface Swap0ForExact1TestCase extends BaseSwapTestCase {
  zeroForOne: true
  exactOut: true
  amount1: BigNumberish
  sqrtPriceLimit?: BigNumber
}
interface Swap1ForExact0TestCase extends BaseSwapTestCase {
  zeroForOne: false
  exactOut: true
  amount0: BigNumberish
  sqrtPriceLimit?: BigNumber
}
interface SwapToHigherPrice extends BaseSwapTestCase {
  zeroForOne: false
  sqrtPriceLimit: BigNumber
}
interface SwapToLowerPrice extends BaseSwapTestCase {
  zeroForOne: true
  sqrtPriceLimit: BigNumber
}
type SwapTestCase =
  | SwapExact0For1TestCase
  | Swap0ForExact1TestCase
  | SwapExact1For0TestCase
  | Swap1ForExact0TestCase
  | SwapToHigherPrice
  | SwapToLowerPrice

function formatTokenAmount(num: BigNumberish): string {
  return new Decimal(num.toString()).dividedBy(new Decimal(10).pow(18)).toPrecision(5)
}

function formatPrice(price: BigNumberish): string {
  return new Decimal(price.toString()).dividedBy(new Decimal(2).pow(96)).pow(2).toPrecision(5)
}

function swapCaseToDescription(testCase: SwapTestCase): string {
  const priceClause = testCase?.sqrtPriceLimit ? ` to price ${formatPrice(testCase.sqrtPriceLimit)}` : ''
  if ('exactOut' in testCase) {
    if (testCase.exactOut) {
      if (testCase.zeroForOne) {
        return `swap token0 for exactly ${formatTokenAmount(testCase.amount1)} token1${priceClause}`
      } else {
        return `swap token1 for exactly ${formatTokenAmount(testCase.amount0)} token0${priceClause}`
      }
    } else {
      if (testCase.zeroForOne) {
        return `swap exactly ${formatTokenAmount(testCase.amount0)} token0 for token1${priceClause}`
      } else {
        return `swap exactly ${formatTokenAmount(testCase.amount1)} token1 for token0${priceClause}`
      }
    }
  } else {
    if (testCase.zeroForOne) {
      return `swap token0 for token1${priceClause}`
    } else {
      return `swap token1 for token0${priceClause}`
    }
  }
}

type PairFunctions = ReturnType<typeof createPairFunctions>

// can't use address zero because the ERC20 token does not allow it
const SWAP_RECIPIENT_ADDRESS = constants.AddressZero.slice(0, -1) + '1'
const BURN_RECIPIENT_ADDRESS = constants.AddressZero.slice(0, -1) + '2'

async function executeSwap(
  pair: MockTimeUniswapV3Pair,
  testCase: SwapTestCase,
  pairFunctions: PairFunctions
): Promise<ContractTransaction> {
  let swap: ContractTransaction
  if ('exactOut' in testCase) {
    if (testCase.exactOut) {
      if (testCase.zeroForOne) {
        swap = await pairFunctions.swap0ForExact1(testCase.amount1, SWAP_RECIPIENT_ADDRESS)
      } else {
        swap = await pairFunctions.swap1ForExact0(testCase.amount0, SWAP_RECIPIENT_ADDRESS)
      }
    } else {
      if (testCase.zeroForOne) {
        swap = await pairFunctions.swapExact0For1(testCase.amount0, SWAP_RECIPIENT_ADDRESS)
      } else {
        swap = await pairFunctions.swapExact1For0(testCase.amount1, SWAP_RECIPIENT_ADDRESS)
      }
    }
  } else {
    if (testCase.zeroForOne) {
      swap = await pairFunctions.swapToLowerPrice(testCase.sqrtPriceLimit, SWAP_RECIPIENT_ADDRESS)
    } else {
      swap = await pairFunctions.swapToHigherPrice(testCase.sqrtPriceLimit, SWAP_RECIPIENT_ADDRESS)
    }
  }
  return swap
}

const DEFAULT_PAIR_SWAP_TESTS: SwapTestCase[] = [
  // swap large amounts in/out
  {
    zeroForOne: true,
    exactOut: false,
    amount0: expandTo18Decimals(1),
  },
  {
    zeroForOne: false,
    exactOut: false,
    amount1: expandTo18Decimals(1),
  },
  {
    zeroForOne: true,
    exactOut: true,
    amount1: expandTo18Decimals(1),
  },
  {
    zeroForOne: false,
    exactOut: true,
    amount0: expandTo18Decimals(1),
  },
  // swap small amounts in/out
  {
    zeroForOne: true,
    exactOut: false,
    amount0: 1000,
  },
  {
    zeroForOne: false,
    exactOut: false,
    amount1: 1000,
  },
  {
    zeroForOne: true,
    exactOut: true,
    amount1: 1000,
  },
  {
    zeroForOne: false,
    exactOut: true,
    amount0: 1000,
  },
  // swap arbitrary input to price
  {
    sqrtPriceLimit: encodePriceSqrt(5, 2),
    zeroForOne: false,
  },
  {
    sqrtPriceLimit: encodePriceSqrt(2, 5),
    zeroForOne: true,
  },
  {
    sqrtPriceLimit: encodePriceSqrt(5, 2),
    zeroForOne: true,
  },
  {
    sqrtPriceLimit: encodePriceSqrt(2, 5),
    zeroForOne: false,
  },
]

interface Position {
  tickLower: number
  tickUpper: number
  liquidity: BigNumberish
}

interface PairTestCase {
  description: string
  feeAmount: number
  tickSpacing: number
  startingPrice: BigNumber
  positions: Position[]
  swapTests?: SwapTestCase[]
}

const TEST_PAIRS: PairTestCase[] = [
  {
    description: 'low fee, 1:1 price, 2e18 max range liquidity',
    feeAmount: FeeAmount.LOW,
    tickSpacing: TICK_SPACINGS[FeeAmount.LOW],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.LOW]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.LOW]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, 1:1 price, 2e18 max range liquidity',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'high fee, 1:1 price, 2e18 max range liquidity',
    feeAmount: FeeAmount.HIGH,
    tickSpacing: TICK_SPACINGS[FeeAmount.HIGH],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.HIGH]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.HIGH]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, 10:1 price, 2e18 max range liquidity',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(10, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.HIGH]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.HIGH]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, 1:10 price, 2e18 max range liquidity',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 10),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.HIGH]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.HIGH]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, 1:1 price, 0 liquidity, all liquidity around current price',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.HIGH]),
        tickUpper: -TICK_SPACINGS[FeeAmount.MEDIUM],
        liquidity: expandTo18Decimals(2),
      },
      {
        tickLower: TICK_SPACINGS[FeeAmount.HIGH],
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, 1:1 price, additional liquidity around current price',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.HIGH]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.HIGH]),
        liquidity: expandTo18Decimals(2),
      },
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.HIGH]),
        tickUpper: -TICK_SPACINGS[FeeAmount.MEDIUM],
        liquidity: expandTo18Decimals(2),
      },
      {
        tickLower: TICK_SPACINGS[FeeAmount.HIGH],
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'low fee, large liquidity around current price (stable swap)',
    feeAmount: FeeAmount.LOW,
    tickSpacing: TICK_SPACINGS[FeeAmount.LOW],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: -TICK_SPACINGS[FeeAmount.LOW],
        tickUpper: TICK_SPACINGS[FeeAmount.LOW],
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, token0 liquidity only',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: 0,
        tickUpper: 2000 * TICK_SPACINGS[FeeAmount.MEDIUM],
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'medium fee, token1 liquidity only',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: -2000 * TICK_SPACINGS[FeeAmount.MEDIUM],
        tickUpper: 0,
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'close to max price',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(BigNumber.from(2).pow(127), 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'close to min price',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, BigNumber.from(2).pow(127)),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        liquidity: expandTo18Decimals(2),
      },
    ],
  },
  {
    description: 'max full range liquidity at 1:1 price with default fee',
    feeAmount: FeeAmount.MEDIUM,
    tickSpacing: TICK_SPACINGS[FeeAmount.MEDIUM],
    startingPrice: encodePriceSqrt(1, 1),
    positions: [
      {
        tickLower: getMinTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        tickUpper: getMaxTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
        liquidity: getMaxLiquidityPerTick(TICK_SPACINGS[FeeAmount.MEDIUM]),
      },
    ],
  },
]

describe.only('UniswapV3Pair swap tests', () => {
  const [wallet] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof createFixtureLoader>

  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet])
  })

  for (const pairCase of TEST_PAIRS) {
    describe(pairCase.description, () => {
      const pairCaseFixture = async () => {
        const { createPair, token0, token1, swapTargetCallee: swapTarget } = await pairFixture(
          [wallet],
          waffle.provider
        )
        const pair = await createPair(pairCase.feeAmount, pairCase.tickSpacing)
        const pairFunctions = createPairFunctions({ swapTarget, token0, token1, pair })
        await pair.initialize(pairCase.startingPrice)
        // mint all positions
        for (const position of pairCase.positions) {
          await pairFunctions.mint(wallet.address, position.tickLower, position.tickUpper, position.liquidity)
        }

        const [pairBalance0, pairBalance1] = await Promise.all([
          token0.balanceOf(pair.address),
          token1.balanceOf(pair.address),
        ])

        return { token0, token1, pair, pairFunctions, pairBalance0, pairBalance1, swapTarget }
      }

      let token0: TestERC20
      let token1: TestERC20

      let pairBalance0: BigNumber
      let pairBalance1: BigNumber

      let pair: MockTimeUniswapV3Pair
      let swapTarget: TestUniswapV3Callee
      let pairFunctions: PairFunctions

      beforeEach('load fixture', async () => {
        ;({ token0, token1, pair, pairFunctions, pairBalance0, pairBalance1, swapTarget } = await loadFixture(
          pairCaseFixture
        ))
      })

      afterEach('check can burn positions', async () => {
        for (const { liquidity, tickUpper, tickLower } of pairCase.positions) {
          await pair.burn(BURN_RECIPIENT_ADDRESS, tickLower, tickUpper, liquidity)
          await pair.collect(BURN_RECIPIENT_ADDRESS, tickLower, tickUpper, MaxUint128, MaxUint128)
        }
      })

      for (const testCase of pairCase.swapTests ?? DEFAULT_PAIR_SWAP_TESTS) {
        it(swapCaseToDescription(testCase), async () => {
          const slot0 = await pair.slot0()
          const tx = executeSwap(pair, testCase, pairFunctions)
          try {
            await tx
          } catch (error) {
            expect({
              swapError: error.message,
              pairBalance0: pairBalance0.toString(),
              pairBalance1: pairBalance1.toString(),
              pairPriceBefore: formatPrice(slot0.sqrtPriceX96),
              tickBefore: slot0.tick,
            }).to.matchSnapshot('swap error')
            return
          }
          const [
            pairBalance0After,
            pairBalance1After,
            slot0After,
            feeGrowthGlobal0X128,
            feeGrowthGlobal1X128,
          ] = await Promise.all([
            token0.balanceOf(pair.address),
            token1.balanceOf(pair.address),
            pair.slot0(),
            pair.feeGrowthGlobal0X128(),
            pair.feeGrowthGlobal1X128(),
          ])
          const pairBalance0Delta = pairBalance0After.sub(pairBalance0)
          const pairBalance1Delta = pairBalance1After.sub(pairBalance1)

          // check all the events were emitted corresponding to balance changes
          if (pairBalance0Delta.eq(0)) await expect(tx).to.not.emit(token0, 'Transfer')
          else if (pairBalance0Delta.lt(0))
            await expect(tx)
              .to.emit(token0, 'Transfer')
              .withArgs(pair.address, SWAP_RECIPIENT_ADDRESS, pairBalance0Delta.mul(-1))
          else await expect(tx).to.emit(token0, 'Transfer').withArgs(wallet.address, pair.address, pairBalance0Delta)

          if (pairBalance1Delta.eq(0)) await expect(tx).to.not.emit(token1, 'Transfer')
          else if (pairBalance1Delta.lt(0))
            await expect(tx)
              .to.emit(token1, 'Transfer')
              .withArgs(pair.address, SWAP_RECIPIENT_ADDRESS, pairBalance1Delta.mul(-1))
          else await expect(tx).to.emit(token1, 'Transfer').withArgs(wallet.address, pair.address, pairBalance1Delta)

          // check that the swap event was emitted too
          await expect(tx)
            .to.emit(pair, 'Swap')
            .withArgs(
              swapTarget.address,
              SWAP_RECIPIENT_ADDRESS,
              pairBalance0Delta,
              pairBalance1Delta,
              slot0After.sqrtPriceX96,
              slot0After.tick
            )

          const executionPrice = new Decimal(pairBalance1Delta.toString()).div(pairBalance0Delta.toString()).mul(-1)

          expect({
            amount0Before: pairBalance0.toString(),
            amount1Before: pairBalance1.toString(),
            amount0Delta: pairBalance0Delta.toString(),
            amount1Delta: pairBalance1Delta.toString(),
            feeGrowthGlobal0X128Delta: feeGrowthGlobal0X128.toString(),
            feeGrowthGlobal1X128Delta: feeGrowthGlobal1X128.toString(),
            tickBefore: slot0.tick,
            pairPriceBefore: formatPrice(slot0.sqrtPriceX96),
            tickAfter: slot0After.tick,
            pairPriceAfter: formatPrice(slot0After.sqrtPriceX96),
            executionPrice: executionPrice.toPrecision(5),
          }).to.matchSnapshot('balances')
        })
      }
    })
  }
})
