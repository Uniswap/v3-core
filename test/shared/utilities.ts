import {BigNumber, BigNumberish, utils, constants, Contract, Wallet, ContractTransaction} from 'ethers'
import {Decimal} from 'decimal.js'
import {assert} from 'chai'

export const MIN_TICK = -7732
export const MAX_TICK = 7732

export const LIQUIDITY_MIN = 10 ** 3

export enum FeeVote {
  FeeVote0 = 0,
  FeeVote1 = 1,
  FeeVote2 = 2,
  FeeVote3 = 3,
  FeeVote4 = 4,
  FeeVote5 = 5,
}
export const FEES: {[vote in FeeVote]: number} = {
  [FeeVote.FeeVote0]: 5,
  [FeeVote.FeeVote1]: 10,
  [FeeVote.FeeVote2]: 30,
  [FeeVote.FeeVote3]: 60,
  [FeeVote.FeeVote4]: 100,
  [FeeVote.FeeVote5]: 200,
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

export type SwapFunction = (
  amount: number | string | BigNumber,
  to: Wallet | string
) => Promise<{amountOut: BigNumber; tx: ContractTransaction}>
export interface SwapFunctions {
  swap0For1: SwapFunction
  swap1For0: SwapFunction
}
export function swapFunctions({
  token0,
  token1,
  swapTarget,
  pair,
  from,
}: {
  from: Wallet
  swapTarget: Contract
  token0: Contract
  token1: Contract
  pair: Contract
}): SwapFunctions {
  /**
   * Execute a swap against the pair of the input token in the input amount, sending proceeds to the given to address
   */
  async function _swap(
    inputToken: Contract,
    amountIn: number | string | BigNumber,
    to: Wallet | string
  ): Promise<{amountOut: BigNumber; tx: ContractTransaction}> {
    const method = inputToken === token0 ? 'swap0For1' : 'swap1For0'

    await inputToken.connect(from).transfer(swapTarget.address, amountIn)

    const data = utils.defaultAbiCoder.encode(
      ['uint256', 'address'],
      [amountIn, typeof to === 'string' ? to : to.address]
    )
    const amountOut = await pair.connect(from).callStatic[method](amountIn, swapTarget.address, data)
    const tx = await pair.connect(from)[method](amountIn, swapTarget.address, data)
    return {tx, amountOut}
  }

  function swap0For1(amount: number | string | BigNumber, to: Wallet | string): ReturnType<typeof _swap> {
    return _swap(token0, amount, to)
  }

  function swap1For0(amount: number | string | BigNumber, to: Wallet | string): ReturnType<typeof _swap> {
    return _swap(token1, amount, to)
  }

  return {swap0For1, swap1For0}
}
