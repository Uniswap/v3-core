import { BigNumber, bigNumberify, getAddress, keccak256, solidityPack } from 'ethers/utils'

import { CHAIN_ID } from './constants'

export function expandTo18Decimals(n: number): BigNumber {
  return bigNumberify(n).mul(bigNumberify(10).pow(18))
}

interface Approve {
  owner: string
  spender: string
  value: BigNumber
}

export function getApprovalDigest(address: string, approve: Approve, nonce: BigNumber, expiration: BigNumber): string {
  return keccak256(
    solidityPack(
      ['bytes1', 'bytes1', 'address', 'bytes32'],
      [
        '0x19',
        '0x00',
        address,
        keccak256(
          solidityPack(
            ['address', 'address', 'uint256', 'uint256', 'uint256', 'uint256'],
            [approve.owner, approve.spender, approve.value, nonce, expiration, CHAIN_ID]
          )
        )
      ]
    )
  )
}

export function getCreate2Address(
  factoryAddress: string,
  token0Address: string,
  token1Address: string,
  bytecode: string
): string {
  const create2Inputs = [
    '0xff',
    factoryAddress,
    keccak256(solidityPack(['address', 'address', 'uint256'], [token0Address, token1Address, CHAIN_ID])),
    keccak256(bytecode)
  ]

  const sanitizedInputs = `0x${create2Inputs.map(i => i.slice(2)).join('')}`

  return getAddress(`0x${keccak256(sanitizedInputs).slice(-40)}`)
}
