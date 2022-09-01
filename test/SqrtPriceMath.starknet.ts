import { SqrtPriceMathTest__WC__SqrtPriceMathTest_compiled} from '../typechain-types'
import BN from 'bn.js'
import { Uint256 } from '../typechain-types/SqrtPriceMathTest__WC__SqrtPriceMathTest_compiled';
import { expect } from './shared/expect'
import { encodePriceSqrt, expandTo18Decimals, MaxUint128 } from './shared/utilities'
import { getStarknetContractFactory } from 'hardhat-warp/dist/testing'

var Q128 = new BN(2).pow(new BN(128))
var MaxUint256 = new BN("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
function toUint256(x: number | BN | string): Uint256 {
  var num = new BN(x);
  return {high: num.div(Q128), low: num.mod(Q128)};
}

function toBN(x: Uint256) {
  return new BN(x.high).mul(Q128).add(new BN(x.low));
}

function Uint256toString(x: Uint256) {
    return toBN(x).toString();
}

describe('SqrtPriceMath', () => {
  let sqrtPriceMath: SqrtPriceMathTest__WC__SqrtPriceMathTest_compiled
  beforeEach('deploy SqrtPriceMathTest', async () => {
    const sqrtPriceMathTestFactory = await getStarknetContractFactory('SqrtPriceMathTest')
    sqrtPriceMath = (await sqrtPriceMathTestFactory.deploy()) as SqrtPriceMathTest__WC__SqrtPriceMathTest_compiled
  })

  describe('#getNextSqrtPriceFromInput', () => {
    // it('fails if price is zero', async () => {
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(0, 0, toUint256(expandTo18Decimals(1).div(10).toNumber()), 0)).to.be.reverted
    // })

    // it('fails if liquidity is zero', async () => {
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(1, 0, toUint256(expandTo18Decimals(1).div(10).toNumber()), 1)).to.be.reverted
    // })

    // it('fails if input amount overflows the price', async () => {
    //   const price = new BN(2).pow(new BN(160)).sub(new BN(1))
    //   const liquidity = 1024
    //   const amountIn = 1024
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(price, liquidity, toUint256(amountIn), 0)).to.be.reverted
    // })

    it('any input amount cannot underflow the price', async () => {
      const price = 1
      const liquidity = 1
      const amountIn = new BN(2).pow(new BN(255))
      const res = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(price, liquidity, toUint256(amountIn), 1)
      expect(res[0].toString()).to.eq('1')
    })

    it('returns input price if amount in is zero and zeroForOne = true', async () => {
      const price = encodePriceSqrt(1, 1).toString()
      const res = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(price, expandTo18Decimals(1).div(10).toString(), toUint256(0), 1)
      expect(res[0].toString()).to.eq(price)
    })

    it('returns input price if amount in is zero and zeroForOne = false', async () => {
      const price = encodePriceSqrt(1, 1).toString()
      const res = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(price, expandTo18Decimals(1).div(10).toString(), toUint256(0), 0)
      expect(res[0].toString()).to.eq(price)
    })

    it('returns the minimum price for max inputs', async () => {
      const sqrtP = new BN(2).pow(new BN(160)).sub(new BN(1))
      const liquidity = MaxUint128
      const maxAmountNoOverflow = MaxUint256.sub(new BN(liquidity.shl(96).div(sqrtP.toNumber()).toNumber()))
      const res = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(sqrtP.toString(), liquidity.toString(), toUint256(maxAmountNoOverflow.toString()), 1)
      expect(res[0].toString()).to.eq('1')
    })

    it('input amount of 0.1 token1', async () => {
      const sqrtQ = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(
        encodePriceSqrt(1, 1).toString(),
        expandTo18Decimals(1).toString(),
        toUint256(expandTo18Decimals(1).div(10).toString()),
        0
      )
      expect(sqrtQ[0].toString()).to.eq('87150978765690771352898345369')
    })

    it('input amount of 0.1 token0', async () => {
      const sqrtQ = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(
        encodePriceSqrt(1, 1).toString(),
        expandTo18Decimals(1).toString(),
        toUint256(expandTo18Decimals(1).div(10).toString()),
        1
      )
      expect(sqrtQ[0].toString()).to.eq('72025602285694852357767227579')
    })

    it('amountIn > type(uint96).max and zeroForOne = true', async () => {
      const res = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(
        encodePriceSqrt(1, 1).toString(),
        expandTo18Decimals(10).toString(),
        toUint256(new BN(2).pow(new BN(100))),
        1
      )
      // perfect answer:
      // https://www.wolframalpha.com/input/?i=624999999995069620+-+%28%281e19+*+1+%2F+%281e19+%2B+2%5E100+*+1%29%29+*+2%5E96%29
    
      expect(res[0].toString()).to.eq('624999999995069620')
    })

    it('can return 1 with enough amountIn and zeroForOne = true', async () => {
      const res = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(encodePriceSqrt(1, 1).toString(), 1, toUint256(MaxUint256.div(new BN(2)).toString()), 1)
      expect(res[0].toString()).to.eq('1')
    })

    // it('zeroForOne = true gas', async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetNextSqrtPriceFromInput(
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       expandTo18Decimals(1).div(10),
    //       true
    //     )
    //   )
    // })

    // it('zeroForOne = false gas', async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetNextSqrtPriceFromInput(
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       expandTo18Decimals(1).div(10),
    //       false
    //     )
    //   )
    // })
  })

  describe('#getNextSqrtPriceFromOutput', () => {
    // it('fails if price is zero', async () => {
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(0, 0, toUint256(expandTo18Decimals(1).div(10).toNumber()), 0)).to.be.reverted
    // })

    // it('fails if liquidity is zero', async () => {
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(1, 0, toUint256(expandTo18Decimals(1).div(10).toNumber()), 1)).to.be.reverted
    // })

    // it('fails if output amount is exactly the virtual reserves of token0', async () => {
    //   const price = '20282409603651670423947251286016'
    //   const liquidity = 1024
    //   const amountOut = 4
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price, liquidity, toUint256(amountOut), 0)).to.be.reverted
    // })

    // it('fails if output amount is greater than virtual reserves of token0', async () => {
    //   const price = '20282409603651670423947251286016'
    //   const liquidity = 1024
    //   const amountOut = 5
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price, liquidity, toUint256(amountOut), 0)).to.be.reverted
    // })

    // it('fails if output amount is greater than virtual reserves of token1', async () => {
    //   const price = '20282409603651670423947251286016'
    //   const liquidity = 1024
    //   const amountOut = 262145
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price, liquidity, toUint256(amountOut), 1)).to.be.reverted
    // })

    // it('fails if output amount is exactly the virtual reserves of token1', async () => {
    //   const price = '20282409603651670423947251286016'
    //   const liquidity = 1024
    //   const amountOut = 262144
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price, liquidity, toUint256(amountOut), 1)).to.be.reverted
    // })

    it('succeeds if output amount is just less than the virtual reserves of token1', async () => {
      const price = '20282409603651670423947251286016'
      const liquidity = 1024
      const amountOut = 262143
      const sqrtQ = await sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price, liquidity, toUint256(amountOut), 1)
      expect(sqrtQ[0].toString()).to.eq('77371252455336267181195264')
    })

    // it('puzzling echidna test', async () => {
    //   const price = '20282409603651670423947251286016'
    //   const liquidity = 1024
    //   const amountOut = 4

    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price, liquidity, toUint256(amountOut.toString()), 0)).to.be.reverted
    // })

    it('returns input price if amount in is zero and zeroForOne = true', async () => {
      const price = encodePriceSqrt(1, 1)
      const res = await sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price.toString(), expandTo18Decimals(1).div(10).toString(), toUint256(0), 1)
      expect(res[0].toString()).to.eq(price)
    })

    it('returns input price if amount in is zero and zeroForOne = false', async () => {
      const price = encodePriceSqrt(1, 1)
      const res = await sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(price.toString(), expandTo18Decimals(1).div(10).toString(), toUint256(0), 0)
      expect(res[0].toString()).to.eq(price.toString())
    })

    it('output amount of 0.1 token1', async () => {
      const sqrtQ = await sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(
        encodePriceSqrt(1, 1).toString(),
        expandTo18Decimals(1).toString(),
        toUint256(expandTo18Decimals(1).div(10).toString()),
        0
      )
      expect(sqrtQ[0].toString()).to.eq('88031291682515930659493278152')
    })

    it('output amount of 0.1 token1', async () => {
      const sqrtQ = await sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(
        encodePriceSqrt(1, 1).toString(),
        expandTo18Decimals(1).toString(),
        toUint256(expandTo18Decimals(1).div(10).toString()),
        1
      )
      expect(sqrtQ[0].toString()).to.eq('71305346262837903834189555302')
    })

    // it('reverts if amountOut is impossible in zero for one direction', async () => {
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(encodePriceSqrt(1, 1).toString(), 1, toUint256(MaxUint256), 1)).to.be
    //     .reverted
    // })

    // it('reverts if amountOut is impossible in one for zero direction', async () => {
    //   await expect(sqrtPriceMath.getNextSqrtPriceFromOutput_fedf2b5f(encodePriceSqrt(1, 1).toString(), 1, toUint256(MaxUint256), 0)).to
    //     .be.reverted
    // })

    // it('zeroForOne = true gas', async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetNextSqrtPriceFromOutput(
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       expandTo18Decimals(1).div(10),
    //       true
    //     )
    //   )
    // })

    // it('zeroForOne = false gas', async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetNextSqrtPriceFromOutput(
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       expandTo18Decimals(1).div(10),
    //       false
    //     )
    //   )
    // })
  })

  describe('#getAmount0Delta', () => {
    it('returns 0 if liquidity is 0', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta_2c32d4b6(encodePriceSqrt(1, 1).toString(), encodePriceSqrt(2, 1).toString(), 0, 1)

      expect(Uint256toString(amount0[0])).to.eq('0')
    })
    it('returns 0 if prices are equal', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta_2c32d4b6(encodePriceSqrt(1, 1).toString(), encodePriceSqrt(1, 1).toString(), 0, 1)

      expect(Uint256toString(amount0[0])).to.eq('0')
    })

    it('returns 0.1 amount1 for price of 1 to 1.21', async () => {
      const amount0 = await sqrtPriceMath.getAmount0Delta_2c32d4b6(
        encodePriceSqrt(1, 1).toString(),
        encodePriceSqrt(121, 100).toString(),
        expandTo18Decimals(1).toString(),
        1
      )
      expect(Uint256toString(amount0[0])).to.eq('90909090909090910')

      const amount0RoundedDown = await sqrtPriceMath.getAmount0Delta_2c32d4b6(
        encodePriceSqrt(1, 1).toString(),
        encodePriceSqrt(121, 100).toString(),
        expandTo18Decimals(1).toString(),
        0
      )

      expect(Uint256toString(amount0RoundedDown[0])).to.eq(toBN(amount0[0]).sub(new BN(1)).toString())
    })

    it('works for prices that overflow', async () => {
      const amount0Up = await sqrtPriceMath.getAmount0Delta_2c32d4b6(
        encodePriceSqrt(new BN(2).pow(new BN(90)).toString(), 1).toString(),
        encodePriceSqrt(new BN(2).pow(new BN(96)).toString(), 1).toString(),
        expandTo18Decimals(1).toString(),
        1
      )
      const amount0Down = await sqrtPriceMath.getAmount0Delta_2c32d4b6(
        encodePriceSqrt(new BN(2).pow(new BN(90)).toString(), 1).toString(),
        encodePriceSqrt(new BN(2).pow(new BN(96)).toString(), 1).toString(),
        expandTo18Decimals(1).toString(),
        0
      )
      expect(Uint256toString(amount0Up[0])).to.eq(toBN(amount0Down[0]).add(new BN(1)).toString())
    })

    // it(`gas cost for amount0 where roundUp = true`, async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetAmount0Delta(
    //       encodePriceSqrt(100, 121),
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       true
    //     )
    //   )
    // })

    // it(`gas cost for amount0 where roundUp = true`, async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetAmount0Delta(
    //       encodePriceSqrt(100, 121),
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       false
    //     )
    //   )
    // })
  })

  describe('#getAmount1Delta', () => {
    it('returns 0 if liquidity is 0', async () => {
      const amount1 = await sqrtPriceMath.getAmount1Delta_48a0c5bd(encodePriceSqrt(1, 1).toString(), encodePriceSqrt(2, 1).toString(), 0, 1)

      expect(Uint256toString(amount1[0])).to.eq('0')
    })
    it('returns 0 if prices are equal', async () => {
      const amount1 = await sqrtPriceMath.getAmount0Delta_2c32d4b6(encodePriceSqrt(1, 1).toString(), encodePriceSqrt(1, 1).toString(), 0, 1)

      expect(Uint256toString(amount1[0])).to.eq('0')
    })

    it('returns 0.1 amount1 for price of 1 to 1.21', async () => {
      const amount1 = await sqrtPriceMath.getAmount1Delta_48a0c5bd(
        encodePriceSqrt(1, 1).toString(),
        encodePriceSqrt(121, 100).toString(),
        expandTo18Decimals(1).toString(),
        1
      )

      expect(Uint256toString(amount1[0])).to.eq('100000000000000000')
      const amount1RoundedDown = await sqrtPriceMath.getAmount1Delta_48a0c5bd(
        encodePriceSqrt(1, 1).toString(),
        encodePriceSqrt(121, 100).toString(),
        expandTo18Decimals(1).toString(),
        0
      )

      expect(Uint256toString(amount1RoundedDown[0])).to.eq(toBN(amount1[0]).sub(new BN(1)).toString())
    })

    // it(`gas cost for amount0 where roundUp = true`, async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetAmount0Delta(
    //       encodePriceSqrt(100, 121),
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       true
    //     )
    //   )
    // })

    // it(`gas cost for amount0 where roundUp = false`, async () => {
    //   await snapshotGasCost(
    //     sqrtPriceMath.getGasCostOfGetAmount0Delta(
    //       encodePriceSqrt(100, 121),
    //       encodePriceSqrt(1, 1),
    //       expandTo18Decimals(1),
    //       false
    //     )
    //   )
    // })
  })

  describe('swap computation', () => {
    it('sqrtP * sqrtQ overflows', async () => {
      // getNextSqrtPriceInvariants(1025574284609383690408304870162715216695788925244,50015962439936049619261659728067971248,406,true)
      const sqrtP = '1025574284609383690408304870162715216695788925244'
      const liquidity = '50015962439936049619261659728067971248'
      const zeroForOne = 1
      const amountIn = '406'

      const sqrtQ = await sqrtPriceMath.getNextSqrtPriceFromInput_aa58276a(sqrtP, liquidity, toUint256(amountIn), zeroForOne)
      expect(sqrtQ[0].toString()).to.eq('1025574284609383582644711336373707553698163132913')

      const amount0Delta = await sqrtPriceMath.getAmount0Delta_2c32d4b6(sqrtQ[0], sqrtP, liquidity, 1)
      expect(Uint256toString(amount0Delta[0])).to.eq('406')
    })
  })
})
