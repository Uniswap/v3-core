import {writeFileSync} from 'fs'
import {resolve} from 'path'
import ALL_TICKS from './all-ticks.json'
import {BigNumber} from 'bignumber.js'

const MIN_TICK = ALL_TICKS[0][0]
const MAX_TICK = ALL_TICKS[ALL_TICKS.length - 1][0]

BigNumber.config({EXPONENTIAL_AT: 99999999})

interface Element {
  searchKey: BigNumber
  value: string
}

// sorts by search key
function elementComparator({searchKey: sk1}: Element, {searchKey: sk2}: Element) {
  if (sk1.lt(sk2)) return -1
  if (sk1.gt(sk2)) return 1
  throw new Error('duplicate search key')
}

const ALL_ELEMENTS: Element[] = ALL_TICKS.map(([tickIndex, price]) => ({
  searchKey: new BigNumber(tickIndex),
  value: new BigNumber(price).toString(),
})).sort(elementComparator)

function generateBlock(elems: Element[], paramName: string, numSpaces: number): string {
  const spaces = Array(numSpaces).fill(' ').join('')
  if (elems.length === 0) {
    throw new Error(`Called with 0 elements`)
  } else if (elems.length === 1) {
    return `${spaces}return ${elems[0].value};`
  } else if (elems.length === 2) {
    return `${spaces}if (${paramName} <= ${elems[0].searchKey.toString()}) return ${elems[0].value}; else return ${
      elems[1].value
    };`
  } else {
    const middleIndex = Math.floor(elems.length / 2)
    const middleKey = elems[middleIndex].searchKey
    const firstHalf = elems.slice(0, middleIndex)
    const secondHalf = elems.slice(middleIndex, elems.length)
    return `${spaces}if (${paramName} < ${middleKey.toString()}) {
${generateBlock(firstHalf, paramName, numSpaces + 2)}
${spaces}} else {
${generateBlock(secondHalf, paramName, numSpaces + 2)}
${spaces}}`
  }
}

const PER_CONTRACT = 1000

const SEGMENTS: Array<Element[]> = []
for (let i = 0; i < ALL_ELEMENTS.length; i += PER_CONTRACT) {
  SEGMENTS.push(ALL_ELEMENTS.slice(i, i + PER_CONTRACT))
}

SEGMENTS.forEach((segment, ix) => {
  writeFileSync(
    resolve(__dirname, '..', 'contracts', 'codegen', `GeneratedTickMath${ix}.sol`),
    `/////// This code is generated. Do not modify by hand.
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

contract GeneratedTickMath${ix} {
  function getRatioAtTick(int256 tick) external pure returns (uint256) {
${generateBlock(segment, 'tick', 4)}
  }
}
`
  )
})

writeFileSync(
  resolve(__dirname, '..', 'contracts', 'codegen', 'GeneratedTickMath.sol'),
  `/////// This code is generated. Do not modify by hand.
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IGeneratedTickMathInner {
  function getRatioAtTick(int256 tick) external pure returns (uint256);
}

contract GeneratedTickMath {
  ${SEGMENTS.map((_, ix) => `IGeneratedTickMathInner immutable private g${ix};`).join('\n  ')}
  
  constructor(
    ${SEGMENTS.map((_, ix) => `IGeneratedTickMathInner _g${ix}`).join(',\n    ')}
  ) public {
    ${SEGMENTS.map((_, ix) => `g${ix} = _g${ix};`).join('\n    ')}
  }
  
  function getRatioAtTick(int256 tick) external pure returns (uint256) {
${generateBlock(
  SEGMENTS.map((segment, ix) => ({
    searchKey: segment[segment.length - 1].searchKey,
    value: `g${ix}.getRatioAtTick(tick)`,
  })),
  'tick',
  4
)}
    revert('invalid tick');
  }
}
`
)
