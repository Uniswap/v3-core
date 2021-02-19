import { pseudoRandomBytes } from 'crypto'
import { BigNumber } from 'ethers'

function toBigNumber(bi: bigint): BigNumber {
  return BigNumber.from(bi.toString())
}

export function randomUint256(): BigNumber {
  const buf = pseudoRandomBytes(32)
  return toBigNumber(buf.readBigUInt64LE(0))
    .shl(24 * 8)
    .add(toBigNumber(buf.readBigUInt64LE(8)).shl(16 * 8))
    .add(toBigNumber(buf.readBigUInt64LE(16)).shl(8 * 8))
    .add(toBigNumber(buf.readBigUInt64LE(24)))
}

export function randomUint160(): BigNumber {
  return randomUint256().shr(96)
}

export function randomUint128(): BigNumber {
  return randomUint256().shr(128)
}
