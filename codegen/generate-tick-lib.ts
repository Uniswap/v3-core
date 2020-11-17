import {writeFileSync} from 'fs'
import {resolve} from 'path'
import ALL_TICKS from './all-ticks.json'
import {BigNumber} from 'bignumber.js'

const MIN_TICK = ALL_TICKS[0][0]
const MAX_TICK = ALL_TICKS[ALL_TICKS.length - 1][0]

BigNumber.config({EXPONENTIAL_AT: 99999999})

interface Element {
  searchKey: BigNumber
  value: BigNumber
}

// sorts by search key
function elementComparator({searchKey: sk1}: Element, {searchKey: sk2}: Element) {
  if (sk1.lt(sk2)) return -1
  if (sk1.gt(sk2)) return 1
  throw new Error('duplicate search key')
}

const ALL_ELEMENTS: Element[] = ALL_TICKS.map(([tickIndex, price]) => ({
  searchKey: new BigNumber(tickIndex),
  value: new BigNumber(price),
})).sort(elementComparator)

function generateBlock(elems: Element[], paramName: string, numSpaces: number): string {
  const spaces = Array(numSpaces).join(' ')
  if (elems.length === 0) {
    throw new Error(`Called with 0 elements`)
  } else if (elems.length === 1) {
    return `${spaces}return ${elems[0].value.toString()};`
  } else if (elems.length === 2) {
    return `${spaces}if (${paramName} == ${elems[0].searchKey.toString()}) return ${elems[0].value.toString()}; else return ${elems[1].value.toString()};`
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

writeFileSync(
  resolve(__dirname, '..', 'contracts', 'codegen', 'GeneratedTickMath.sol'),
  `/////// This code is generated. Do not modify by hand.
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

library GeneratedTickMath {
  function getRatioAtTick(int16 tick) internal pure returns (uint256) {
    require(tick >= ${MIN_TICK}, 'GeneratedTickMath::getRatioAtTick: tick must be greater than ${MIN_TICK}');
    require(tick <= ${MAX_TICK}, 'GeneratedTickMath::getRatioAtTick: tick must be less than ${MAX_TICK}');
    
${generateBlock(ALL_ELEMENTS.slice(0, 1100), 'tick', 4)}
  }
}
`
)
