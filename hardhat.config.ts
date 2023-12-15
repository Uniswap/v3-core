import "@typechain/hardhat";

import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'

import '@solarity/hardhat-migrate'

import * as dotenv from "dotenv";
dotenv.config();

const accounts = process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : undefined;

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    ropsten: {
      url: `https://ropsten.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    arbitrumRinkeby: {
      url: `https://arbitrum-rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    arbitrum: {
      url: `https://arbitrum-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    optimismKovan: {
      url: `https://optimism-kovan.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    optimism: {
      url: `https://optimism-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    polygon: {
      url: `https://polygon-mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
    },
    bnb: {
      url: `https://bsc-dataseed.binance.org/`,
    },
    piccadilly: {
      url: `https://rpc1.piccadilly.autonity.org/`,
      accounts
    },
    qdevnet: {
      url: `https://rpc.qdevnet.org`,
      accounts
    },
    qtestnet: {
       url: `https://rpc.qtestnet.org`,
      accounts
    },
    qmainnet: {
      url: `https://rpc.q.org`,
      accounts
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: {
      piccadilly: 'abc',
      qdevnet: 'abc',
      qtestnet: 'abc',
      qmainnet: 'abc',
    },
    customChains: [
      {
        network: 'qdevnet',
        chainId: 35442,
        urls: {
          apiURL: 'http://54.73.188.73:8080/api',
          browserURL: 'http://54.73.188.73:8080',
        },
      },
      {
        network: 'qtestnet',
        chainId: 35443,
        urls: {
          apiURL: 'https://explorer-old.qtestnet.org/api',
          browserURL: 'https://explorer-old.qtestnet.org',
        },
      },
      {
        network: 'qmainnet',
        chainId: 35441,
        urls: {
          apiURL: 'https://explorer.q.org/api',
          browserURL: 'https://explorer.q.org',
        },
      },
      {
        network: `piccadilly`,
        chainId: 65100001,
        urls: {
          apiURL: 'https://piccadilly.autonity.org/api',
          browserURL: 'https://piccadilly.autonity.org',
        },
      },
    ],
  },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 800,
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: 'none',
      },
    },
  },
  typechain: {
    outDir: 'typechain',
    target: 'ethers-v5',
    alwaysGenerateOverloads: true,
    discriminateTypes: true,
  },
}
