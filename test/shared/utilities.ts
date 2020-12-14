import {BigNumber, BigNumberish, utils, constants} from 'ethers'
import bn from 'bignumber.js'
export const getMinTick = (tickSpacing: number) => Math.ceil(-887272 / tickSpacing) * tickSpacing
export const getMaxTick = (tickSpacing: number) => Math.floor(887272 / tickSpacing) * tickSpacing
export const MAX_LIQUIDITY_GROSS_PER_TICK = BigNumber.from('20282409603651670423947251286015')

export enum FeeAmount {
  LOW = 600,
  MEDIUM = 3000,
  HIGH = 9000,
}

export const TICK_SPACINGS: {[amount in FeeAmount]: number} = {
  [FeeAmount.LOW]: 12,
  [FeeAmount.MEDIUM]: 60,
  [FeeAmount.HIGH]: 180,
}

export function expandTo18Decimals(n: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

export function getCreate2Address(
  factoryAddress: string,
  [tokenA, tokenB]: [string, string],
  fee: number,
  tickSpacing: number,
  bytecode: string
): string {
  const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
  const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'uint24', 'int24'],
    [factoryAddress, token0, token1, fee, tickSpacing]
  )
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

bn.config({EXPONENTIAL_AT: 999999})

// returns the sqrt price as a 64x96
export function encodePriceSqrt(reserve1: BigNumberish, reserve0: BigNumberish): BigNumber {
  return BigNumber.from(
    new bn(reserve1.toString())
      .div(reserve0.toString())
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
  )
}

export function getPositionKey(address: string, lowerTick: number, upperTick: number): string {
  return utils.keccak256(utils.solidityPack(['address', 'int24', 'int24'], [address, lowerTick, upperTick]))
}
