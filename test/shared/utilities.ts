import { providers, Contract } from 'ethers'
import {
  BigNumber,
  bigNumberify,
  getAddress,
  keccak256,
  defaultAbiCoder,
  toUtf8Bytes,
  solidityPack
} from 'ethers/utils'

import { CHAIN_ID } from './constants'

const APPROVE_TYPEHASH = keccak256(
  toUtf8Bytes('Approve(address owner,address spender,uint256 value,uint256 nonce,uint256 expiration)')
)

const GET_DOMAIN_SEPARATOR = async (token: Contract) => {
  const name = await token.name()
  return keccak256(
    defaultAbiCoder.encode(
      ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
      [
        keccak256(toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
        keccak256(toUtf8Bytes(name)),
        keccak256(toUtf8Bytes('1')),
        CHAIN_ID,
        token.address
      ]
    )
  )
}

export function expandTo18Decimals(n: number): BigNumber {
  return bigNumberify(n).mul(bigNumberify(10).pow(18))
}

interface Approve {
  owner: string
  spender: string
  value: BigNumber
}

export async function getApprovalDigest(
  token: Contract,
  approve: Approve,
  nonce: BigNumber,
  expiration: BigNumber
): Promise<string> {
  const DOMAIN_SEPARATOR = await GET_DOMAIN_SEPARATOR(token)
  return keccak256(
    solidityPack(
      ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
      [
        '0x19',
        '0x01',
        DOMAIN_SEPARATOR,
        keccak256(
          defaultAbiCoder.encode(
            ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
            [APPROVE_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, expiration]
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
    keccak256(solidityPack(['address', 'address'], [token0Address, token1Address])),
    keccak256(bytecode)
  ]

  const sanitizedInputs = `0x${create2Inputs.map(i => i.slice(2)).join('')}`

  return getAddress(`0x${keccak256(sanitizedInputs).slice(-40)}`)
}

async function mineBlock(provider: providers.Web3Provider, timestamp?: number): Promise<void> {
  await new Promise((resolve, reject) => {
    ;(provider._web3Provider.sendAsync as any)(
      { jsonrpc: '2.0', method: 'evm_mine', params: timestamp ? [timestamp] : [] },
      (error: any, result: any): void => {
        if (error) {
          reject(error)
        } else {
          resolve(result)
        }
      }
    )
  })
}

export async function mineBlocks(
  provider: providers.Web3Provider,
  numberOfBlocks: number,
  timestamp?: number
): Promise<void> {
  await Promise.all([...Array(numberOfBlocks - 1)].map(() => mineBlock(provider)))
  await mineBlock(provider, timestamp)
}
