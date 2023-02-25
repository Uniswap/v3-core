import QuoterV2 from '@uniswap/swap-router-contracts/artifacts/contracts/lens/QuoterV2.sol/QuoterV2.json'
import createDeployContractStep from './meta/createDeployContractStep'

export const DEPLOY_QUOTER_V2 = createDeployContractStep({
  key: 'quoterV2Address',
  artifact: QuoterV2,
  computeArguments(state, config) {
    if (state.v3CoreFactoryAddress === undefined) {
      throw new Error('Missing V3 Core Factory')
    }
    return [state.v3CoreFactoryAddress, config.weth9Address]
  },
})
