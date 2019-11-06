import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { AddressZero, MaxUint256 } from 'ethers/constants'
import { bigNumberify, hexlify } from 'ethers/utils'
import { ecsign } from 'ethereumjs-util'

import { CHAIN_ID } from './shared/constants'
import { expandTo18Decimals, getApprovalDigest } from './shared/utilities'

import ERC20 from '../build/GenericERC20.json'

chai.use(solidity)
const { expect } = chai

const TOKEN_DETAILS = {
  name: 'Test Token',
  symbol: 'TEST',
  decimals: 18,
  totalSupply: expandTo18Decimals(1000)
}
const TEST_AMOUNT = expandTo18Decimals(10)

describe('ERC20', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet, other] = getWallets(provider)

  let token: Contract
  beforeEach(async () => {
    token = await deployContract(wallet, ERC20, [
      TOKEN_DETAILS.name,
      TOKEN_DETAILS.symbol,
      TOKEN_DETAILS.decimals,
      TOKEN_DETAILS.totalSupply,
      CHAIN_ID
    ])
  })

  it('name, symbol, decimals, totalSupply, chainId', async () => {
    expect(await token.name()).to.eq(TOKEN_DETAILS.name)
    expect(await token.symbol()).to.eq(TOKEN_DETAILS.symbol)
    expect(await token.decimals()).to.eq(TOKEN_DETAILS.decimals)
    expect(await token.totalSupply()).to.eq(TOKEN_DETAILS.totalSupply)
    expect(await token.chainId()).to.eq(CHAIN_ID)
  })

  it('transfer', async () => {
    await expect(token.transfer(other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)

    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('burn', async () => {
    await expect(token.burn(TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, AddressZero, TEST_AMOUNT)

    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.totalSupply()).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
  })

  it('approve', async () => {
    await expect(token.approve(other.address, TEST_AMOUNT))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)

    expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
  })

  it('approveMeta', async () => {
    const nonce = await token.nonceFor(wallet.address)
    const expiration = MaxUint256
    const digest = getApprovalDigest(
      token.address,
      { owner: wallet.address, spender: other.address, value: TEST_AMOUNT },
      nonce,
      expiration
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))

    await expect(
      token.approveMeta(wallet.address, other.address, TEST_AMOUNT, nonce, expiration, v, hexlify(r), hexlify(s))
    )
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)

    expect(await token.nonceFor(wallet.address)).to.eq(bigNumberify(1))
    expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
  })

  it('transferFrom', async () => {
    await token.approve(other.address, TEST_AMOUNT)
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)

    expect(await token.allowance(wallet.address, other.address)).to.eq(0)
    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('burnFrom', async () => {
    await token.approve(other.address, TEST_AMOUNT)
    await expect(token.connect(other).burnFrom(wallet.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, AddressZero, TEST_AMOUNT)

    expect(await token.allowance(wallet.address, other.address)).to.eq(0)
    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.totalSupply()).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(0)
  })

  it('transfer:fail', async () => {
    await expect(token.transfer(other.address, TOKEN_DETAILS.totalSupply.add(1))).to.be.revertedWith(
      'ds-math-sub-underflow'
    )
    await expect(token.connect(other).transfer(wallet.address, 1)).to.be.revertedWith('ds-math-sub-underflow')
  })
})
