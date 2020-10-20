import {usePlugin} from '@nomiclabs/buidler/config'

usePlugin('@nomiclabs/buidler-waffle')

export default {
  defaultNetwork: 'buidlerevm',
  networks: {
    buidlerevm: {
      // allowUnlimitedContractSize: true,
    },
  },
  solc: {
    version: '0.6.12',
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  paths: {
    artifacts: './build',
  },
}
