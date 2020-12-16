import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      // blockGasLimit: 12000000,
    },
  },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
}
