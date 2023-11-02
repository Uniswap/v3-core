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

    const INIT_LIQUIDITY = encodePriceSqrt(1, 1)

    let wallet: Wallet;
    let lpRecipient: Wallet;
    let pool: MockTimeUniswapV3Pool;
    let token0: TestERC20
    let token1: TestERC20

    beforeEach('deploy pool', async () => {
        // Create wallets
        [wallet, lpRecipient] = await (ethers as any).getSigners()

        const { token0: _token0, token1: _token1, createPool } = await poolFixture([wallet], waffle.provider)
        token0 = _token0; token1 = _token1;

        pool = await createPool(
            FeeAmount.MEDIUM,
            TICK_SPACINGS[FeeAmount.MEDIUM],
            token0,
            token1
        )
        
        await pool.initialize(INIT_LIQUIDITY)

        await token0.approve(pool.address, constants.MaxUint256)
        await token1.approve(pool.address, constants.MaxUint256)
    })

    it('Create limit order to tick greater than current tick', async () => {
        // Create limit order
        let amount = expandTo18Decimals(5);
        let tickLower = (await pool.slot0()).tick + await pool.tickSpacing()
        await expect(pool.createLimitOrder(
            await lpRecipient.getAddress(),
            tickLower,
            amount
        )).to.emit(pool, 'Mint').withArgs(
            await wallet.getAddress(),
            await lpRecipient.getAddress(),
            tickLower,
            tickLower + await pool.tickSpacing(),
            amount,
            BigNumber.from('14931914022994409'),
            0
        )
    })

})