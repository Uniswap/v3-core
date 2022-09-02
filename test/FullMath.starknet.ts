import {FullMathTest__WC__FullMathTest_compiled} from '../typechain-types'
import {expect} from 'chai';
import { getStarknetContractFactory } from 'hardhat-warp/dist/testing'
import BN from 'bn.js'
import { Uint256 } from '../typechain-types/FullMathTest__WC__FullMathTest_compiled';
import { Decimal } from 'decimal.js'

var Q128 = new BN(2).pow(new BN(128))
var MaxUint256 = new BN("115792089237316195423570985008687907853269984665640564039457584007913129639935")
function toUint256(x: number | BN | string): Uint256 {
    var num = new BN(x);
    return {high: num.div(Q128), low: num.mod(Q128)};
}

function toBN(x: Uint256) {
    return new BN(x.high).mul(Q128).add(new BN(x.low));
}

function Uint256toString(x: Uint256) {
    return x.high.toString() + x.low.toString();
}

Decimal.config({ toExpNeg: -500, toExpPos: 500 })

describe('FullMath', () => {
    let fullMath: FullMathTest__WC__FullMathTest_compiled
    beforeEach('deploy FullMathTest', async () => {
      const factory = await getStarknetContractFactory('FullMathTest')
      fullMath = (await factory.deploy()) as FullMathTest__WC__FullMathTest_compiled
    })
  
    describe('#mulDiv', () => {
      it('reverts if denominator is 0', async () => {
        await expect(fullMath.mulDiv_aa9a0912(toUint256(Q128), toUint256(5), toUint256(0))).to.be.reverted
      })
      it('reverts if denominator is 0 and numerator overflows', async () => {
        await expect(fullMath.mulDiv_aa9a0912(toUint256(Q128), toUint256(Q128), toUint256(0))).to.be.reverted
      })
      it('reverts if output overflows uint256', async () => {
        await expect(fullMath.mulDiv_aa9a0912(toUint256(Q128), toUint256(Q128), toUint256(1))).to.be.reverted
      })
      it('reverts if output overflows uint256', async () => {
        await expect(fullMath.mulDiv_aa9a0912(toUint256(Q128), toUint256(Q128), toUint256(1))).to.be.reverted
      })
      it('reverts on overflow with all max inputs', async () => {
        await expect(fullMath.mulDiv_aa9a0912(toUint256(MaxUint256), toUint256(MaxUint256), toUint256(MaxUint256.sub(new BN(1))))).to.be.reverted
      })
  
      it('all max inputs', async () => {
        const res = await fullMath.mulDiv_aa9a0912(toUint256(MaxUint256), toUint256(MaxUint256), toUint256(MaxUint256))
        expect(Uint256toString(res[0])).to.eq(Uint256toString(toUint256(MaxUint256)))
      })
  
      it('accurate without phantom overflow', async () => {
        const result = toUint256(Q128.div(new BN(3)))
        const res = await fullMath.mulDiv_aa9a0912(
            toUint256(Q128),
            /*0.5=*/ toUint256(new BN(50).mul(Q128).div(new BN(100))),
            /*1.5=*/ toUint256(new BN(150).mul(Q128).div(new BN(100)))
          )
        expect(
            Uint256toString(res[0])
        ).to.eq(Uint256toString(result))
      })
  
      it('accurate with phantom overflow', async () => {
        const result = toUint256(new BN(4375).mul(Q128).div(new BN(1000)))
        const res = await fullMath.mulDiv_aa9a0912(toUint256(Q128), toUint256(new BN(35).mul(Q128)), toUint256(new BN(8).mul(Q128)))
        expect(Uint256toString(res[0])).to.eq(Uint256toString(result))
      })
  
      it('accurate with phantom overflow and repeating decimal', async () => {
        const result = toUint256(new BN(1).mul(Q128).div(new BN(3)))
        const res = await fullMath.mulDiv_aa9a0912(toUint256(Q128), toUint256(new BN(1000).mul(Q128)), toUint256(new BN(3000).mul(Q128)))
        expect(Uint256toString(res[0])).to.eq(Uint256toString(result))
      })
    })
  
    describe('#mulDivRoundingUp', () => {
      it('reverts if denominator is 0', async () => {
        await expect(fullMath.mulDivRoundingUp_0af8b27f(toUint256(Q128), toUint256(5), toUint256(0))).to.be.reverted
      })
      it('reverts if denominator is 0 and numerator overflows', async () => {
        await expect(fullMath.mulDivRoundingUp_0af8b27f(toUint256(Q128), toUint256(Q128), toUint256(0))).to.be.reverted
      })
      it('reverts if output overflows uint256', async () => {
        await expect(fullMath.mulDivRoundingUp_0af8b27f(toUint256(Q128), toUint256(Q128), toUint256(1))).to.be.reverted
      })
      it('reverts on overflow with all max inputs', async () => {
        await expect(fullMath.mulDivRoundingUp_0af8b27f(toUint256(MaxUint256), toUint256(MaxUint256), toUint256(MaxUint256.sub(new BN(1))))).to.be.reverted
      })
  
      it('reverts if mulDiv overflows 256 bits after rounding up', async () => {
        await expect(
          fullMath.mulDivRoundingUp_0af8b27f(
            toUint256('535006138814359'),
            toUint256('432862656469423142931042426214547535783388063929571229938474969'),
            toUint256('2')
          )
        ).to.be.reverted
      })
  
      it('reverts if mulDiv overflows 256 bits after rounding up case 2', async () => {
        await expect(
          fullMath.mulDivRoundingUp_0af8b27f(
            toUint256('115792089237316195423570985008687907853269984659341747863450311749907997002549'),
            toUint256('115792089237316195423570985008687907853269984659341747863450311749907997002550'),
            toUint256('115792089237316195423570985008687907853269984653042931687443039491902864365164')
          )
        ).to.be.reverted
      })
  
      it('all max inputs', async () => { // FAILS
        const res = await fullMath.mulDivRoundingUp_0af8b27f(toUint256(MaxUint256), toUint256(MaxUint256), toUint256(MaxUint256))
        expect(Uint256toString(res[0])).to.eq(Uint256toString(toUint256(MaxUint256)))
      })
  
      it('accurate without phantom overflow', async () => {
        const result = toUint256(Q128.div(new BN(3)).add(new BN(1)))
        const res = await fullMath.mulDivRoundingUp_0af8b27f(
            toUint256(Q128),
            /*0.5=*/ toUint256(new BN(50).mul(Q128).div(new BN(100))),
            /*1.5=*/ toUint256(new BN(150).mul(Q128).div(new BN(100)))
          )
        expect(
          Uint256toString(res[0])
        ).to.eq(Uint256toString(result))
      })
  
      it('accurate with phantom overflow', async () => {
        const result = toUint256(new BN(4375).mul(Q128).div(new BN(1000)))
        const res = await fullMath.mulDivRoundingUp_0af8b27f(toUint256(Q128), toUint256(new BN(35).mul(Q128)), toUint256(new BN(8).mul(Q128)))
        expect(Uint256toString(res[0])).to.eq(
          Uint256toString(result)
        )
      })
  
      it('accurate with phantom overflow and repeating decimal', async () => { // FAILS
        const result = toUint256(new BN(1).mul(Q128).div(new BN(3)).add(new BN(1)))
        const res = await fullMath.mulDivRoundingUp_0af8b27f(toUint256(Q128), toUint256(new BN(1000).mul(Q128)), toUint256(new BN(3000).mul(Q128)))
        expect(
          Uint256toString(res[0])
        ).to.eq(Uint256toString(result))
      })
    })
  
    
    function pseudoRandomBigNumber() {
      return toUint256(new BN(new Decimal(MaxUint256.toString()).mul(Math.random().toString()).round().toString()))
    }
  
    // tiny fuzzer. unskip to run
    it.skip('check a bunch of random inputs against JS implementation', async () => {
      // generates random inputs
      const tests = Array(1_000)
        .fill(null)
        .map(() => {
          return {
            x: pseudoRandomBigNumber(),
            y: pseudoRandomBigNumber(),
            d: pseudoRandomBigNumber(),
          }
        })
        .map(({ x, y, d }) => {
          return {
            input: {
              x,
              y,
              d,
            },
            floored: fullMath.mulDiv_aa9a0912(x, y, d),
            ceiled: fullMath.mulDivRoundingUp_0af8b27f(x, y, d),
          }
        })
  
      await Promise.all(
        tests.map(async ({ input: { x, y, d }, floored, ceiled }) => {
          if (toBN(d).eq(new BN(0))) {
            await expect(floored).to.be.reverted
            await expect(ceiled).to.be.reverted
            return
          }
  
          if (toBN(x).eq(new BN(0)) || toBN(y).eq(new BN(0))) {
            await expect(floored).to.eq(new BN(0))
            await expect(ceiled).to.eq(new BN(0))
          } else if (toBN(x).mul(toBN(y)).div(toBN(d)).gt(MaxUint256)) {
            await expect(floored).to.be.reverted
            await expect(ceiled).to.be.reverted
          } else {
            expect(await floored).to.eq(toBN(x).mul(toBN(y)).div(toBN(d)))
            expect(await ceiled).to.eq(
              toBN(x)
                .mul(toBN(y))
                .div(toBN(d))
                .add(toBN(x).mul(toBN(y)).mod(toBN(d)).gt(new BN(0)) ? new BN(1) : new BN(0))
            )
          }
        })
      )
    }) 
  })
