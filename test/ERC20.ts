import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { BigNumber, bigNumberify } from 'ethers/utils'

import ERC20 from '../build/ERC20.json'

chai.use(solidity)
const { expect } = chai

const decimalize = (n: number): BigNumber => bigNumberify(n).mul(bigNumberify(10).pow(18))

const name = 'Mock ERC20'
const symbol = 'MOCK'
const decimals = 18
const totalSupply = decimalize(100)
const transferAmount = decimalize(100)

describe('ERC20', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet, walletTo] = getWallets(provider)
  let token: Contract

  beforeEach(async () => {
    token = await deployContract(wallet, ERC20, [name, symbol, decimals, totalSupply])
  })

  it('name, symbol, decimals, totalSupply, balanceOf', async () => {
    expect(await token.name()).to.eq(name)
    expect(await token.symbol()).to.eq(symbol)
    expect(await token.decimals()).to.eq(18)
    expect(await token.totalSupply()).to.eq(totalSupply)
    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply)
  })

  it('transfer', async () => {
    await expect(token.transfer(walletTo.address, transferAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, walletTo.address, transferAmount)

    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(transferAmount))
    expect(await token.balanceOf(walletTo.address)).to.eq(transferAmount)
  })

  it('transferFrom', async () => {
    await expect(token.approve(walletTo.address, transferAmount))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, walletTo.address, transferAmount)

    await expect(token.connect(walletTo).transferFrom(wallet.address, walletTo.address, transferAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, walletTo.address, transferAmount)

    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(transferAmount))
    expect(await token.balanceOf(walletTo.address)).to.eq(transferAmount)
  })

  it('transfer fails', async () => {
    await expect(token.transfer(walletTo.address, totalSupply.add(1))).to.be.revertedWith(
      'SafeMath: subtraction overflow'
    )

    await expect(token.connect(walletTo).transfer(walletTo.address, 1)).to.be.revertedWith(
      'SafeMath: subtraction overflow'
    )
  })
})
