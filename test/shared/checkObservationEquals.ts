import { BigNumber, BigNumberish } from 'ethers'
import { expect } from './expect'

// helper function because we cannot do a simple deep equals with the
// observation result object returned from ethers because it extends array
export default function checkObservationEquals(
  {
    tickCumulative,
    blockTimestamp,
    initialized,
    secondsPerLiquidityCumulativeX128,
  }: {
    tickCumulative: BigNumber
    secondsPerLiquidityCumulativeX128: BigNumber
    initialized: boolean
    blockTimestamp: number
  },
  expected: {
    tickCumulative: BigNumberish
    secondsPerLiquidityCumulativeX128: BigNumberish
    initialized: boolean
    blockTimestamp: number
  }
) {
  expect(
    {
      initialized,
      blockTimestamp,
      tickCumulative: tickCumulative.toString(),
      secondsPerLiquidityCumulativeX128: secondsPerLiquidityCumulativeX128.toString(),
    },
    `observation is equivalent`
  ).to.deep.eq({
    ...expected,
    tickCumulative: expected.tickCumulative.toString(),
    secondsPerLiquidityCumulativeX128: expected.secondsPerLiquidityCumulativeX128.toString(),
  })
}
