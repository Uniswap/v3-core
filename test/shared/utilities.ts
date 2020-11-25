import {BigNumber, BigNumberish, utils, constants} from 'ethers'

export const MIN_TICK = -7351
export const MAX_TICK = 7351
export const MAX_LIQUIDITY_GROSS_PER_TICK = BigNumber.from('5192296858534827628530496329220095')

export enum FeeOption {
  FeeOption0 = 'FeeOption0',
  FeeOption1 = 'FeeOption1',
  FeeOption2 = 'FeeOption2',
  FeeOption3 = 'FeeOption3',
  FeeOption4 = 'FeeOption4',
  FeeOption5 = 'FeeOption5',
}

export const FEES: {[vote in FeeOption]: number} = {
  [FeeOption.FeeOption0]: 6,
  [FeeOption.FeeOption1]: 12,
  [FeeOption.FeeOption2]: 30,
  [FeeOption.FeeOption3]: 60,
  [FeeOption.FeeOption4]: 120,
  [FeeOption.FeeOption5]: 240,
}

export function expandTo18Decimals(n: number): BigNumber {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

export function getCreate2Address(
  factoryAddress: string,
  [tokenA, tokenB]: [string, string],
  fee: number,
  bytecode: string
): string {
  const [token0, token1] = tokenA.toLowerCase() < tokenB.toLowerCase() ? [tokenA, tokenB] : [tokenB, tokenA]
  const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(
    ['address', 'address', 'address', 'uint16'],
    [factoryAddress, token0, token1, fee]
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

export function encodePrice(reserve1: BigNumberish, reserve0: BigNumberish): BigNumber {
  return BigNumber.from(reserve1).mul(BigNumber.from(2).pow(128)).div(reserve0)
}

export function getPositionKey(address: string, lowerTick: number, upperTick: number): string {
  return utils.keccak256(utils.solidityPack(['address', 'int16', 'int16'], [address, lowerTick, upperTick]))
}

// handles if the result is an array (in the case of fixed point struct return values where it's an array of one uint224)
export function bnify2(a: BigNumberish | [BigNumberish] | {0: BigNumberish}): BigNumber {
  if (Array.isArray(a)) {
    return BigNumber.from(a[0])
  } else {
    return BigNumber.from(a)
  }
}
