import { expect } from './shared/expect'
import { LiquidityMathTest__WC__LiquidityMathTest_compiled } from '../typechain-types'
import { getStarknetContractFactory } from 'hardhat-warp'
import BN from 'bn.js'

describe('LiquidityMath', () => {
  let liquidityMath: LiquidityMathTest__WC__LiquidityMathTest_compiled

  beforeEach('deploy LiquidityMathTest', async () => {
    const factory = await getStarknetContractFactory('LiquidityMathTest')
    liquidityMath = (await factory.deploy()) as LiquidityMathTest__WC__LiquidityMathTest_compiled
  })

  describe('#addDelta', () => {
    it('1 + 0', async () => {
      const res = await liquidityMath.addDelta_402d44fb(1, 0)
      expect(res[0].toNumber()).to.eq(1)
    })
    it('1 + -1', async () => {
      const res = await liquidityMath.addDelta_402d44fb(1, new BN(-1).toTwos(128).toString())
      expect(res[0].toNumber()).to.eq(0)
    })
    it('1 + 1', async () => {
      const res = await liquidityMath.addDelta_402d44fb(1, 1)
      expect(res[0].toNumber()).to.eq(2)
    })
    it('2**128-15 + 15 overflows', async () => {
      expect(liquidityMath.addDelta_402d44fb(new BN(2).pow(new BN(128)).subn(15), 15)).to.be.revertedWith('LA')
    })
    it('0 + -1 underflows', async () => {
      expect(liquidityMath.addDelta_402d44fb(0, new BN(-1).toTwos(128).toString())).to.be.revertedWith('LS')
    })
    it('3 + -4 underflows', async () => {
      expect(liquidityMath.addDelta_402d44fb(3, new BN(-4).toTwos(128).toString())).to.be.revertedWith('LS')
    })
  })
})
