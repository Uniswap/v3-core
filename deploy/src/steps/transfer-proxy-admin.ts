import ProxyAdmin from '@openzeppelin/contracts/build/contracts/ProxyAdmin.json'
import { Contract } from '@ethersproject/contracts'
import { MigrationStep } from '../migrations'

export const TRANSFER_PROXY_ADMIN: MigrationStep = async (state, { signer, gasPrice, ownerAddress }) => {
  if (state.proxyAdminAddress === undefined) {
    throw new Error('Missing ProxyAdmin')
  }

  const proxyAdmin = new Contract(state.proxyAdminAddress, ProxyAdmin.abi, signer)

  const owner = await proxyAdmin.owner()
  if (owner === ownerAddress)
    return [
      {
        message: `ProxyAdmin owned by ${ownerAddress} already`,
      },
    ]

  if (owner !== (await signer.getAddress())) {
    throw new Error('ProxyAdmin.owner is not signer')
  }

  const tx = await proxyAdmin.transferOwnership(ownerAddress, { gasPrice })

  return [
    {
      message: `ProxyAdmin ownership set to ${ownerAddress}`,
      hash: tx.hash,
    },
  ]
}
