import NonfungibleTokenPositionDescriptor from '@uniswap/v3-periphery/artifacts/contracts/NonfungibleTokenPositionDescriptor.sol/NonfungibleTokenPositionDescriptor.json'
import createDeployContractStep from './meta/createDeployContractStep'

export const DEPLOY_NFT_POSITION_DESCRIPTOR_V1_3_0 = createDeployContractStep({
  key: 'nonfungibleTokenPositionDescriptorAddressV1_3_0',
  artifact: NonfungibleTokenPositionDescriptor,
  computeLibraries(state) {
    if (state.nftDescriptorLibraryAddressV1_3_0 === undefined) {
      throw new Error('NFTDescriptor library missing')
    }
    return {
      NFTDescriptor: state.nftDescriptorLibraryAddressV1_3_0,
    }
  },
  computeArguments(_, { weth9Address, nativeCurrencyLabelBytes }) {
    return [weth9Address, nativeCurrencyLabelBytes]
  },
})
