import { usePlugin } from '@nomiclabs/buidler/config'

usePlugin('@nomiclabs/buidler-waffle')

export default {
  defaultNetwork: 'buidlerevm',
  solc: {
    version: '0.6.11',
    optimizer: {
      enabled: true,
      runs: 5,
    },
  },
  paths: {
    artifacts: './build',
  },
}
