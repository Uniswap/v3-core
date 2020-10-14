import {TransactionReceipt, TransactionResponse} from '@ethersproject/abstract-provider'
import {expect} from './expect'
import {Contract, BigNumber} from 'ethers'

export default async function snapshotGasCost(
  x:
    | TransactionResponse
    | Promise<TransactionResponse>
    | TransactionReceipt
    | Promise<BigNumber>
    | BigNumber
    | Contract
    | Promise<Contract>
): Promise<void> {
  const resolved = await x
  if ('deployTransaction' in resolved) {
    const receipt = await resolved.deployTransaction.wait()
    expect(receipt.gasUsed.toNumber()).toMatchSnapshot()
  } else if ('wait' in resolved) {
    const waited = await resolved.wait()
    expect(waited.gasUsed.toNumber()).toMatchSnapshot()
  } else if (BigNumber.isBigNumber(resolved)) {
    expect(resolved.toNumber()).toMatchSnapshot()
  }
}
