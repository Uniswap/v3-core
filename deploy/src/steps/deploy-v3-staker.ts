import UniswapV3Staker from '@uniswap/v3-staker/artifacts/contracts/UniswapV3Staker.sol/UniswapV3Staker.json'
import createDeployContractStep from './meta/createDeployContractStep'

const ONE_MINUTE_SECONDS = 60
const ONE_HOUR_SECONDS = ONE_MINUTE_SECONDS * 60
const ONE_DAY_SECONDS = ONE_HOUR_SECONDS * 24
const ONE_MONTH_SECONDS = ONE_DAY_SECONDS * 30
const ONE_YEAR_SECONDS = ONE_DAY_SECONDS * 365

// 2592000
const MAX_INCENTIVE_START_LEAD_TIME = ONE_MONTH_SECONDS
// 1892160000
const MAX_INCENTIVE_DURATION = ONE_YEAR_SECONDS * 2

export const DEPLOY_V3_STAKER = createDeployContractStep({
  key: 'v3StakerAddress',
  artifact: UniswapV3Staker,
  computeArguments(state) {
    if (state.v3CoreFactoryAddress === undefined) {
      throw new Error('Missing V3 Core Factory')
    }
    if (state.nonfungibleTokenPositionManagerAddress === undefined) {
      throw new Error('Missing NFT contract')
    }
    return [
      state.v3CoreFactoryAddress,
      state.nonfungibleTokenPositionManagerAddress,
      MAX_INCENTIVE_START_LEAD_TIME,
      MAX_INCENTIVE_DURATION,
    ]
  },
})
