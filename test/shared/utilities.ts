import {BigNumber, BigNumberish, utils, constants} from 'ethers'

export const MIN_TICK = -7351
export const MAX_TICK = 7351

export enum FeeVote {
  FeeVote0 = 0,
  FeeVote1 = 1,
  FeeVote2 = 2,
  FeeVote3 = 3,
  FeeVote4 = 4,
  FeeVote5 = 5,
}

export const FEES: {[vote in FeeVote]: number} = {
  [FeeVote.FeeVote0]: 6,
  [FeeVote.FeeVote1]: 12,
  [FeeVote.FeeVote2]: 30,
  [FeeVote.FeeVote3]: 60,
  [FeeVote.FeeVote4]: 120,
  [FeeVote.FeeVote5]: 240,
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
  const constructorArgumentsEncoded = utils.defaultAbiCoder.encode(
    ['address', 'address', 'address'],
    [factoryAddress, token0, token1]
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

export function encodePrice(reserve1: BigNumber, reserve0: BigNumber): BigNumber {
  return reserve1.mul(BigNumber.from(2).pow(112)).div(reserve0)
}

export function getPositionKey(address: string, lowerTick: number, upperTick: number, feeVote: FeeVote): string {
  return utils.keccak256(
    utils.solidityPack(['address', 'int16', 'int16', 'uint8'], [address, lowerTick, upperTick, feeVote])
  )
}

// handles if the result is an array (in the case of fixed point struct return values where it's an array of one uint224)
export function bnify2(a: BigNumberish | [BigNumberish] | {0: BigNumberish}): BigNumber {
  if (Array.isArray(a)) {
    return BigNumber.from(a[0])
  } else {
    return BigNumber.from(a)
  }
}
