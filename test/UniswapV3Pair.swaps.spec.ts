import { ContractReceipt } from '@ethersproject/contracts/src.ts/index'
import { Decimal } from 'decimal.js'
import { BigNumber, BigNumberish, ContractTransaction, Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { MockTimeUniswapV3Pair } from '../typechain/MockTimeUniswapV3Pair'
import { TestERC20 } from '../typechain/TestERC20'
import { expect } from './shared/expect'
import { pairFixture } from './shared/fixtures'
import snapshotGasCost from './shared/snapshotGasCost'

import {
  createPairFunctions,
  encodePriceSqrt,
  expandTo18Decimals,
  FeeAmount,
  getMaxTick,
  getMinTick,
  TICK_SPACINGS,
} from './shared/utilities'

const createFixtureLoader = waffle.createFixtureLoader
const { constants } = ethers

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
}

const TEST_PAIRS: PairTestCase[] = [
  {
    description: 'default low fee at 1:1 price with 2e18 liquidity across range',
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
]

interface BaseSwapTestCase {
  zeroForOne: boolean
  sqrtPriceLimit?: BigNumber
  recipient: string | Wallet
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
  return new Decimal(price.toString()).dividedBy(new Decimal(2).pow(128)).toPrecision(5)
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
        return `swap exactly ${formatTokenAmount(testCase.amount1)} token0 for token1${priceClause}`
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

async function executeSwap(
  pair: MockTimeUniswapV3Pair,
  testCase: SwapTestCase,
  pairFunctions: PairFunctions
): Promise<ContractTransaction> {
  let swap: ContractTransaction
  if ('exactOut' in testCase) {
    if (testCase.exactOut) {
      if (testCase.zeroForOne) {
        swap = await pairFunctions.swap0ForExact1(testCase.amount1, testCase.recipient)
      } else {
        swap = await pairFunctions.swap1ForExact0(testCase.amount0, testCase.recipient)
      }
    } else {
      if (testCase.zeroForOne) {
        swap = await pairFunctions.swapExact0For1(testCase.amount0, testCase.recipient)
      } else {
        swap = await pairFunctions.swapExact1For0(testCase.amount1, testCase.recipient)
      }
    }
  } else {
    if (testCase.zeroForOne) {
      swap = await pairFunctions.swapToLowerPrice(testCase.sqrtPriceLimit, testCase.recipient)
    } else {
      swap = await pairFunctions.swapToHigherPrice(testCase.sqrtPriceLimit, testCase.recipient)
    }
  }
  return swap
}

describe.only('UniswapV3Pair swap tests', () => {
  const [wallet, other] = waffle.provider.getWallets()

  let loadFixture: ReturnType<typeof createFixtureLoader>

  const SWAP_TEST_CASES: SwapTestCase[] = [
    {
      amount0: expandTo18Decimals(1),
      zeroForOne: true,
      exactOut: false,
      recipient: other,
    },
  ]

  before('create fixture loader', async () => {
    loadFixture = createFixtureLoader([wallet, other])
  })

  for (const pairCase of TEST_PAIRS) {
    describe(pairCase.description, () => {
      const pairCaseFixture = async () => {
        const { createPair, token0, token1, swapTarget } = await pairFixture([wallet, other], waffle.provider)
        const pair = await createPair(pairCase.feeAmount, pairCase.tickSpacing)
        const pairFunctions = createPairFunctions({ token0, token1, pair, swapTarget })
        await pair.initialize(pairCase.startingPrice)
        // mint all positions
        for (const position of pairCase.positions) {
          await pairFunctions.mint(constants.AddressZero, position.tickLower, position.tickUpper, position.liquidity)
        }

        const [balance0, balance1, pairBalance0, pairBalance1] = await Promise.all([
          token0.balanceOf(wallet.address),
          token1.balanceOf(wallet.address),
          token0.balanceOf(pair.address),
          token1.balanceOf(pair.address),
        ])

        return { token0, token1, pair, pairFunctions, balance0, balance1, pairBalance0, pairBalance1 }
      }

      let token0: TestERC20
      let token1: TestERC20

      let balance0: BigNumber
      let balance1: BigNumber
      let pairBalance0: BigNumber
      let pairBalance1: BigNumber

      let pair: MockTimeUniswapV3Pair
      let pairFunctions: PairFunctions

      beforeEach('load fixture', async () => {
        ;({ token0, token1, balance0, balance1, pair, pairFunctions, pairBalance0, pairBalance1 } = await loadFixture(
          pairCaseFixture
        ))
      })

      for (const testCase of SWAP_TEST_CASES) {
        it(swapCaseToDescription(testCase), async () => {
          await executeSwap(pair, testCase, pairFunctions)
          const [balance0After, balance1After, pairBalance0After, pairBalance1After] = await Promise.all([
            token0.balanceOf(wallet.address),
            token1.balanceOf(wallet.address),
            token0.balanceOf(pair.address),
            token1.balanceOf(pair.address),
          ])
          const balance0Delta = balance0After.sub(balance0)
          const balance1Delta = balance1After.sub(balance1)
          const pairBalance0Delta = pairBalance0After.sub(pairBalance0)
          const pairBalance1Delta = pairBalance1After.sub(pairBalance1)

          expect({
            balance0Delta: formatTokenAmount(balance0Delta),
            balance1Delta: formatTokenAmount(balance1Delta),
            pairBalance0Delta: formatTokenAmount(pairBalance0Delta),
            pairBalance1Delta: formatTokenAmount(pairBalance1Delta),
          }).to.matchSnapshot('balances')
        })
      }
    })
  }
})
