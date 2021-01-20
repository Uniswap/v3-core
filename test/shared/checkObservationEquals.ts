import { BigNumber, BigNumberish } from 'ethers'
import { expect } from './expect'

// helper function because we cannot do a simple deep equals with the
// observation result object returned from ethers because it extends array
export default function checkObservationEquals(
  {
    tickCumulative,
    blockTimestamp,
    initialized,
    liquidityCumulative,
  }: {
    tickCumulative: BigNumber
    liquidityCumulative: BigNumber
    initialized: boolean
    blockTimestamp: number
  },
  expected: {
    tickCumulative: BigNumberish
    liquidityCumulative: BigNumberish
    initialized: boolean
    blockTimestamp: number
  }
) {
  expect(
    {
      initialized,
      blockTimestamp,
      tickCumulative: tickCumulative.toString(),
      liquidityCumulative: liquidityCumulative.toString(),
    },
    `observation is equivalent`
  ).to.deep.eq({
    ...expected,
    tickCumulative: expected.tickCumulative.toString(),
    liquidityCumulative: expected.liquidityCumulative.toString(),
  })
}
