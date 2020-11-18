import {ethers} from 'hardhat'
import {BigNumber, constants, Signer} from 'ethers'
import {TickMathTest} from '../typechain/TickMathTest'
import {PriceMathTest} from '../typechain/PriceMathTest'
import {expect} from './shared/expect'
import {MAX_TICK, MIN_TICK} from './shared/utilities'

describe.only('boundaries', () => {
  let tickMath: TickMathTest
  let priceMath: PriceMathTest
  before('deploy TickMathTest', async () => {
    const tickMathTestFactory = await ethers.getContractFactory('TickMathTest')
    tickMath = (await tickMathTestFactory.deploy()) as TickMathTest

    const priceMathTestFactory = await ethers.getContractFactory('PriceMathTest')
    priceMath = (await priceMathTestFactory.deploy()) as PriceMathTest
  })

  describe('price bounds', () => {
    it('lowest possible price - highest liquidity value s.t. amount0 fits in uint256', async () => {
      // https://www.wolframalpha.com/input/?i=x+*+2**%2856+%2B+248%2F2%29+%2F+floor%28sqrt%2888+*+2**248%29%29+%3C+2**256
      // 2**203 < liquidity < 2**204
      const liquidity = BigNumber.from('15074415055704415487657032870421184960266150541022980787404799')
      const price = await tickMath.getPrice(MIN_TICK)

      const {reserve0} = await priceMath.getVirtualReservesAtPrice(price, liquidity, true)

      expect(reserve0).to.be.eq('115792089237316195423570985008687907853269984665640564039457576326547795765937')

      await expect(priceMath.getVirtualReservesAtPrice(price, liquidity.add(1), true)).to.be.revertedWith(
        'FullMath: FULLDIV_OVERFLOW'
      )
    })

    it('high price - maximum amount1 value', async () => {
      // https://www.wolframalpha.com/input/?i=x+*+ceil%28sqrt%28303234240456628314812755527551896419093891969393794634489866122815+*+2**38%29%29+%2F+2**%2856+%2B+38%2F2%29+%3C+2**256
      // 2**203 < liquidity < 2**204
      const liquidity = BigNumber.from('15151984855205294382360462632373566578269258345102592278933113')
      const price = await tickMath.getPrice(MAX_TICK)

      const {reserve1} = await priceMath.getVirtualReservesAtPrice(price, liquidity, true)

      expect(reserve1).to.be.eq('115792089237316195423570985008687907853269984665640564039457583438440672419665')

      await expect(priceMath.getVirtualReservesAtPrice(price, liquidity.add(1), true)).to.be.revertedWith(
        'FullMath: FULLDIV_OVERFLOW'
      )
    })

    it('mid price', async () => {
      const liquidity = BigNumber.from(2).pow(256).sub(1)
      const price = await tickMath.getPrice(0)

      const {reserve0, reserve1} = await priceMath.getVirtualReservesAtPrice(price, liquidity, true)

      expect(reserve0).to.be.eq(liquidity)
      expect(reserve1).to.be.eq(liquidity)
    })
  })
})
