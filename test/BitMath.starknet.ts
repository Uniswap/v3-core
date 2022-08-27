import {BitMathTest__WC__BitMathTest_compiled} from '../typechain-types'
import {expect} from 'chai';
import { getStarknetContractFactory } from 'hardhat-warp/dist/testing'
import BN from 'bn.js'

describe('BitMath', () => {
  let bitMath: BitMathTest__WC__BitMathTest_compiled

  beforeEach('deploy BitMathTest', async () => {
    const factory = await getStarknetContractFactory('BitMathTest')
    const contract = await factory.deploy()
    bitMath = await (contract.deployed()) as BitMathTest__WC__BitMathTest_compiled
  })

  describe('#mostSignificantBit', () => {
    it('0', async () => {
      await expect(bitMath.mostSignificantBit_e6bcbc65({low:0, high:0})).to.be.reverted

    })
    it('1', async () => {
      const res = await bitMath.mostSignificantBit_e6bcbc65({low: 1, high: 0})
      expect(res[0].toNumber()).to.eq(0)
    })
    it('2', async () => {
      const res = await bitMath.mostSignificantBit_e6bcbc65({low: 2, high: 0})
      expect(res[0].toNumber()).to.eq(1)
    })
    it('all powers of 2', async () => {
      const low = [...Array(128)].map(
        (_, i) => bitMath.mostSignificantBit_e6bcbc65({low: new BN(2).pow(new BN(i)), high: 0})
      )
      const high = [...Array(128)].map(
        (_, i) => bitMath.mostSignificantBit_e6bcbc65({low: 0, high: new BN(2).pow(new BN(i))})
      )
      const results = await Promise.all([...low, ...high])
      const res = results.map((element) => element[0].toNumber());
      expect(res).to.deep.eq([...Array(256)].map((_, i) => i));
    })
    it('uint256(-1)', async () => {
      const res = await bitMath.mostSignificantBit_e6bcbc65({
        low: new BN(2).pow(new BN(128)).sub(new BN(1)), 
        high: new BN(2).pow(new BN(128)).sub(new BN(1)),
      })
      expect(res[0].toNumber()).to.eq(255)
    })
  })

  describe('#leastSignificantBit', () => {
    it('0', async () => {
      await expect(bitMath.leastSignificantBit_d230d23f({low:0, high:0})).to.be.reverted
    })
    it('1', async () => {
      const res = await bitMath.leastSignificantBit_d230d23f({low: 1, high: 0})
      expect(res[0].toNumber()).to.eq(0)
    })
    it('2', async () => {
      const res = await bitMath.leastSignificantBit_d230d23f({low: 2, high: 0})
      expect(res[0].toNumber()).to.eq(1)
    })
    it('all powers of 2', async () => {
      const low = [...Array(128)].map(
        (_, i) => bitMath.leastSignificantBit_d230d23f({low: new BN(2).pow(new BN(i)), high: 0})
      )
      const high = [...Array(128)].map(
        (_, i) => bitMath.leastSignificantBit_d230d23f({low: 0, high: new BN(2).pow(new BN(i))})
      )
      const results = await Promise.all([...low, ...high])
      const res = results.map((element) => element[0].toNumber());
      expect(res).to.deep.eq([...Array(256)].map((_, i) => i));
    })
    it('uint256(-1)', async () => {
      const res = await bitMath.leastSignificantBit_d230d23f({
        low: new BN(2).pow(new BN(128)).sub(new BN(1)), 
        high: new BN(2).pow(new BN(128)).sub(new BN(1)),
      })
      expect(res[0].toNumber()).to.eq(0)
    })
  })
})
