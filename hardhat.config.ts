import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'

export default {
  networks: {
    // default configuration is fine
    hardhat: {
      allowUnlimitedContractSize: true,
      blockGasLimit: 12000000,
    },
  },
  solidity: {
    version: '0.6.12',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
}
