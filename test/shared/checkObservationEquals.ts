import { BigNumber, BigNumberish } from 'ethers'
import { expect } from './expect'

// helper function because we cannot do a simple deep equals with the
// observation result object returned from ethers because it extends array
export default function checkObservationEquals(
  actual: BigNumber,
  expected: {
    tickCumulative: BigNumberish
    liquidityCumulative: number
    blockTimestamp: number
  }
) {
  const blockTimestamp = actual.shr(96)
  const tickCumulative = actual.shr(40).mod(BigNumber.from(2).pow(56))
  const liquidityCumulative = actual.mod(BigNumber.from(2).pow(40))
  expect(
    {
      blockTimestamp,
      liquidityCumulative,
      tickCumulative: tickCumulative.toString(),
    },
    `observation is equivalent`
  ).to.deep.eq({
    ...expected,
    tickCumulative: expected.tickCumulative.toString(),
  })
}
