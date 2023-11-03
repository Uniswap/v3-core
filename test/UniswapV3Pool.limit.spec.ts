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

const { constants } = ethers

describe('UniswapV3Pool limit orders tests', () => {

    const INIT_LIQUIDITY = encodePriceSqrt(1, 1)

    let wallet: Wallet;
    let lpRecipient1: Wallet;
    let lpRecipient2: Wallet;
    let pool: MockTimeUniswapV3Pool;
    let token0: TestERC20
    let token1: TestERC20
    let swapTarget: TestUniswapV3Callee

    beforeEach('deploy pool', async () => {
        // Create wallets
        [wallet, lpRecipient1, lpRecipient2] = await (ethers as any).getSigners()

        const {
            token0: _token0,
            token1: _token1,
            createPool,
            swapTargetCallee
        } = await poolFixture([wallet], waffle.provider)
        swapTarget = swapTargetCallee
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

        await token0.approve(swapTarget.address, constants.MaxUint256)
        await token1.approve(swapTarget.address, constants.MaxUint256)
    })

    it('Create limit order to tick greater than current tick', async () => {
        // Should emit 'Mint' event
        let amount = expandTo18Decimals(5)
        let tickLower = (await pool.slot0()).tick + await pool.tickSpacing()
        await expect(pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount
        )).to.emit(pool, 'Mint').withArgs(
            await wallet.getAddress(),
            await lpRecipient1.getAddress(),
            tickLower,
            tickLower + await pool.tickSpacing(),
            amount,
            BigNumber.from('14931914022994409'),
            0
        )
    })

    it('Create limit order to tick smaller than current tick', async () => {
        // Should emit 'Mint' event
        let amount = expandTo18Decimals(5)
        let tickLower = (await pool.slot0()).tick - await pool.tickSpacing()
        await expect(pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount
        )).to.emit(pool, 'Mint').withArgs(
            await wallet.getAddress(),
            await lpRecipient1.getAddress(),
            tickLower,
            tickLower + await pool.tickSpacing(),
            amount,
            0,
            BigNumber.from('14976774779553905')
        )
    })

    it('Creating limit orders should revert if tick is equal to current tick', async () => {
        // Should emit 'Mint' event
        let amount = expandTo18Decimals(5)
        let tickLower = (await pool.slot0()).tick
        await expect(pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount
        )).to.be.revertedWith('TL')
    })

    it('Create limit order and collect before fulfilling', async () => {
        // Create limit order
        let amount = expandTo18Decimals(5)
        let tickLower = (await pool.slot0()).tick + await pool.tickSpacing()
        await pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount
        )

        await expect(pool.connect(lpRecipient1).collectLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower
        )).to.emit(pool, "Burn").withArgs(
            await lpRecipient1.getAddress(),
            tickLower,
            tickLower + await pool.tickSpacing(),
            amount,
            BigNumber.from('14931914022994408'), // Internally rounded down by 1 unit
            0
        )
    })

    it('Fulfill limit order by swapping tokens (greater tick)', async () => {
        // Create limit order
        const amount = expandTo18Decimals(5)
        const tickLower = (await pool.slot0()).tick + await pool.tickSpacing()
        await pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount
        )

        // swap tokens oneForZero
        const amountIn = expandTo18Decimals(10);
        await swapTarget.swapExact1For0(
            pool.address,
            amountIn,
            await wallet.getAddress(),
            MAX_SQRT_RATIO.sub(1)
        )

        // Withdraw swapped tokens + fees
        console.log(await token1.balanceOf(lpRecipient1.address))
        await pool.connect(lpRecipient1).collectLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower
        )
        // TODO: Compare the balances, difference should be equal to
        // swapped tokens + collected fees
        console.log(await token1.balanceOf(lpRecipient1.address))
    })

    it('Fulfill limit order by swapping tokens (smaller tick)', async () => {
        // Create limit order
        const amount = expandTo18Decimals(5)
        const tickLower = (await pool.slot0()).tick - await pool.tickSpacing()
        await pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount
        )

        // swap tokens oneForZero
        const amountIn = expandTo18Decimals(10);
        await swapTarget.swapExact0For1(
            pool.address,
            amountIn,
            await wallet.getAddress(),
            MIN_SQRT_RATIO.add(1)
        )

        // Withdraw swapped tokens + fees
        console.log(await token0.balanceOf(lpRecipient1.address))
        await pool.connect(lpRecipient1).collectLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower
        )
        // TODO: Compare the balances, difference should be equal to
        // swapped tokens + collected fees
        console.log(await token0.balanceOf(lpRecipient1.address))
    })

    it('Two users open limit orders (greater)', async () => {
        // Create limit order 1
        const amount1 = expandTo18Decimals(5)
        const tickLower = (await pool.slot0()).tick + await pool.tickSpacing()
        await pool.createLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower,
            amount1
        )

        // Create limit order 2
        const amount2 = expandTo18Decimals(10)
        await pool.createLimitOrder(
            await lpRecipient2.getAddress(),
            tickLower,
            amount2
        )

        // swap tokens oneForZero
        const amountIn = expandTo18Decimals(15);
        await swapTarget.swapExact1For0(
            pool.address,
            amountIn,
            await wallet.getAddress(),
            MAX_SQRT_RATIO.sub(1)
        )

        // Withdraw 1 swapped tokens + fees
        const balance11Before = await token1.balanceOf(lpRecipient1.address);
        console.log(balance11Before)
        await pool.connect(lpRecipient1).collectLimitOrder(
            await lpRecipient1.getAddress(),
            tickLower
        )
        // TODO: Compare the balances, difference should be equal to
        // swapped tokens + collected fees
        const balance11Diff = (await token1.balanceOf(lpRecipient1.address)).sub(balance11Before);
        console.log(balance11Diff)

        // Withdraw 2 swapped tokens + fees
        const balance12Before = await token1.balanceOf(lpRecipient2.address);
        console.log(balance12Before)
        await pool.connect(lpRecipient2).collectLimitOrder(
            await lpRecipient2.getAddress(),
            tickLower
        )
        // TODO: Compare the balances, difference should be equal to
        // swapped tokens + collected fees
        const balance12Diff = (await token1.balanceOf(lpRecipient2.address)).sub(balance12Before);
        console.log(balance12Diff)

        // User1 balance should be less than User2
        // since it has provided less liquidity
        expect(balance11Diff.lt(balance12Diff)).to.be.true
    });

})