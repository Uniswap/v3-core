import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { AddressZero, MaxUint256 } from 'ethers/constants'
import { bigNumberify, hexlify, keccak256, defaultAbiCoder, toUtf8Bytes } from 'ethers/utils'
import { ecsign } from 'ethereumjs-util'

import { expandTo18Decimals, getApprovalDigest } from './shared/utilities'

import ERC20 from '../build/ERC20.json'

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
      TOKEN_DETAILS.totalSupply
    ])
  })

  it('name, symbol, decimals, totalSupply, balanceOf, DOMAIN_SEPARATOR, PERMIT_TYPEHASH', async () => {
    const name = await token.name()
    expect(name).to.eq(TOKEN_DETAILS.name)
    expect(await token.symbol()).to.eq(TOKEN_DETAILS.symbol)
    expect(await token.decimals()).to.eq(TOKEN_DETAILS.decimals)
    expect(await token.totalSupply()).to.eq(TOKEN_DETAILS.totalSupply)
    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply)
    expect(await token.DOMAIN_SEPARATOR()).to.eq(
      keccak256(
        defaultAbiCoder.encode(
          ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
          [
            keccak256(
              toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
            ),
            keccak256(toUtf8Bytes(name)),
            keccak256(toUtf8Bytes('1')),
            1,
            token.address
          ]
        )
      )
    )
    expect(await token.PERMIT_TYPEHASH()).to.eq(
      keccak256(toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)'))
    )
  })

  it('transfer', async () => {
    await expect(token.transfer(other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('forfeit', async () => {
    await expect(token.forfeit(TEST_AMOUNT))
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

  it('transferFrom', async () => {
    await token.approve(other.address, TEST_AMOUNT)
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(wallet.address, other.address)).to.eq(0)
    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('transferFrom:max', async () => {
    await token.approve(other.address, MaxUint256)
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(wallet.address, other.address)).to.eq(MaxUint256)
    expect(await token.balanceOf(wallet.address)).to.eq(TOKEN_DETAILS.totalSupply.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('forfeitFrom', async () => {
    await token.approve(other.address, TEST_AMOUNT)
    await expect(token.connect(other).forfeitFrom(wallet.address, TEST_AMOUNT))
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

  it('permit', async () => {
    const nonce = await token.nonces(wallet.address)
    const expiration = MaxUint256
    const digest = await getApprovalDigest(
      token,
      { owner: wallet.address, spender: other.address, value: TEST_AMOUNT },
      nonce,
      expiration
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))

    await expect(token.permit(wallet.address, other.address, TEST_AMOUNT, nonce, expiration, v, hexlify(r), hexlify(s)))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.nonces(wallet.address)).to.eq(bigNumberify(1))
    expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
  })
})
