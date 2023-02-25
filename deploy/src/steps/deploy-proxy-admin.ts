import ProxyAdmin from '@openzeppelin/contracts/build/contracts/ProxyAdmin.json'
import createDeployContractStep from './meta/createDeployContractStep'

export const DEPLOY_PROXY_ADMIN = createDeployContractStep({
  key: 'proxyAdminAddress',
  artifact: ProxyAdmin,
})
