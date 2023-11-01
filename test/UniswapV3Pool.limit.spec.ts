import { Decimal } from 'decimal.js'
import { BigNumber, BigNumberish, ContractTransaction, Wallet } from 'ethers'
import { ethers, waffle } from 'hardhat'
import { MockTimeUniswapV3Pool } from '../typechain/MockTimeUniswapV3Pool'
import { TestERC20 } from '../typechain/TestERC20'

import { TestUniswapV3Callee } from '../typechain/TestUniswapV3Callee'
import { expect } from './shared/expect'
import { poolFixture } from './shared/fixtures'
import { formatPrice, formatTokenAmount } from './shared/format'
import {
  createPoolFunctions,
  encodePriceSqrt,
  expandTo18Decimals,
  FeeAmount,
  getMaxLiquidityPerTick,
  getMaxTick,
  getMinTick,
  MAX_SQRT_RATIO,
  MaxUint128,
  MIN_SQRT_RATIO,
  TICK_SPACINGS,
} from './shared/utilities'

Decimal.config({ toExpNeg: -500, toExpPos: 500 })

const createFixtureLoader = waffle.createFixtureLoader
const { constants } = ethers

describe('UniswapV3Pool limit orders tests', () => {

    const INIT_LIQUIDITY = expandTo18Decimals(2);

    let deployer: Wallet;
    let lp1: Wallet;
    let lpRecipient: Wallet;
    let swapper1: Wallet;
    let pool: MockTimeUniswapV3Pool;
    let token0: TestERC20
    let token1: TestERC20

    beforeEach('deploy pool', async () => {
        // Create wallets
        [deployer, lp1, lpRecipient, swapper1] = await (ethers as any).getSigners()

        const { token0: _token0, token1: _token1, createPool } = await poolFixture([deployer], waffle.provider)
        token0 = _token0; token1 = _token1;

        pool = await createPool(
            FeeAmount.MEDIUM,
            TICK_SPACINGS[FeeAmount.MEDIUM],
            token0,
            token1
        )
        
        await pool.initialize(INIT_LIQUIDITY)
    })

    it("Create limit order to tick greater than current tick", async () => {
        // Mint tokens to lp1
        let amount = expandTo18Decimals(5);
        let tickLower = (await pool.slot0()).tick + await pool.tickSpacing() 
        await pool.createLimitOrder(
            lpRecipient.address,
            tickLower,
            amount
        )
    })

})