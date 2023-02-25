import TickLens from '@uniswap/v3-periphery/artifacts/contracts/lens/TickLens.sol/TickLens.json'
import createDeployContractStep from './meta/createDeployContractStep'

export const DEPLOY_TICK_LENS = createDeployContractStep({
  key: 'tickLensAddress',
  artifact: TickLens,
})
