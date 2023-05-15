import { ethers, network } from 'hardhat'
import fs from 'fs'

async function main() {
  const [deployer] = await ethers.getSigners()

  console.log('Network: ', network.name)
  console.log('Deployer address: ', deployer.address)

  const LeChainFactory = await ethers.getContractFactory('LeChainFactory')
  let factory = await LeChainFactory.deploy()
  console.log('factory created: ', factory.address)

  const contracts = {
    NetworkName: network.name,
    ChainId: network.config.chainId,
    Deployer: deployer.address,
    Factory: factory.address
  }
  fs.writeFileSync(`./deployments/${network.name}.json`, JSON.stringify(contracts, null, 2))
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
