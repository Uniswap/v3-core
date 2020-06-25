import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'

import PriceMathTest from '../build/PriceMathTest.json'

chai.use(solidity)

describe('UniswapV3ERC20', () => {
  const provider = new MockProvider({
    hardfork: 'istanbul',
    mnemonic: 'horn horn horn horn horn horn horn horn horn horn horn horn',
    gasLimit: 9999999
  })
  const [wallet] = provider.getWallets()

  let priceMath: Contract
  beforeEach(async () => {
    priceMath = await deployContract(wallet, PriceMathTest, [])
  })

  describe('#getTradeToRatio', () => {
    describe('edge cases', () => {
      it('0 reserves', async () => {
        await priceMath.getTradeToRatio(0, 0, 0, [0])
      })
    })
  })
})
