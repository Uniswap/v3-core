import { BigNumber, BigNumberish, utils, constants, providers } from 'ethers'
import { Decimal } from 'decimal.js'
import { assert } from 'chai'

export const MIN_TICK = -7802
export const MAX_TICK = 7802

export const LIQUIDITY_MIN = 10 ** 3

export const OVERRIDES = {
  gasLimit: 9999999,
}

export enum FeeVote {
  FeeVote0 = 0,
  FeeVote1 = 1,
  FeeVote2 = 2,
  FeeVote3 = 3,
}

export function expandTo18Decimals(n: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

export function getCreate2Address(
  factoryAddress: string,
  [tokenA, tokenB]: [string, string],
  bytecode: string
): string {
  const [token0, token1] = tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA]
  const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(['address', 'address'], [token0, token1])
  const create2Inputs = [
    '0xff',
    factoryAddress,
    // salt
    constants.HashZero,
    // init code. bytecode + constructor arguments
    utils.keccak256(bytecode + constructorArgumentsEncoded.substr(2)),
  ]
  const sanitizedInputs = `0x${create2Inputs.map((i) => i.slice(2)).join('')}`
  return utils.getAddress(`0x${utils.keccak256(sanitizedInputs).slice(-40)}`)
}

export async function mineBlock(provider: providers.Web3Provider, timestamp: number): Promise<void> {
  return provider.send('evm_mine', [timestamp])
}

export function encodePrice(reserve0: BigNumber, reserve1: BigNumber) {
  return [
    reserve1.mul(BigNumber.from(2).pow(112)).div(reserve0),
    reserve0.mul(BigNumber.from(2).pow(112)).div(reserve1),
  ]
}

export function getPositionKey(address: string, lowerTick: number, upperTick: number, feeVote: FeeVote): string {
  return utils.keccak256(
    utils.solidityPack(['address', 'int16', 'int16', 'uint8'], [address, lowerTick, upperTick, feeVote])
  )
}

const LN101 = Decimal.ln('1.01')
export function getExpectedTick(reserve0: BigNumber, reserve1: BigNumber): number {
  if (reserve0.isZero() && reserve1.isZero()) return 0
  assert(!reserve1.isZero())

  const price = new Decimal(reserve1.toString()).div(new Decimal(reserve0.toString()))
  // log_1.01(price) = ln(price) / ln(1.01) by the base change rule
  const rawTick = Decimal.ln(price).div(LN101)
  const tick = rawTick.floor().toNumber()

  // verify
  assert(new Decimal('1.01').pow(tick).lte(price))
  assert(new Decimal('1.01').pow(tick + 1).gt(price))

  return tick
}

// handles if the result is an array (in the case of fixed point struct return values where it's an array of one uint224)
export function bnify2(a: BigNumberish | [BigNumberish]): BigNumber {
  if (Array.isArray(a)) {
    return BigNumber.from(a[0])
  } else {
    return BigNumber.from(a)
  }
}
