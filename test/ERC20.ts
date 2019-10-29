import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { AddressZero, MaxUint256 } from 'ethers/constants'
import { BigNumber, bigNumberify, keccak256, solidityPack, hexlify } from 'ethers/utils'
import { ecsign } from 'ethereumjs-util'

import ERC20 from '../build/GenericERC20.json'

chai.use(solidity)
const { expect } = chai

const decimalize = (n: number): BigNumber => bigNumberify(n).mul(bigNumberify(10).pow(18))

const name = 'Mock Token'
const symbol = 'MOCK'
const decimals = 18

const chainId = 1

const totalSupply = decimalize(100)
const testAmount = decimalize(10)

describe('ERC20', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet, other] = getWallets(provider)
  let token: Contract

  beforeEach(async () => {
    token = await deployContract(wallet, ERC20, [name, symbol, decimals, totalSupply, chainId])
  })

  it('name, symbol, decimals, totalSupply', async () => {
    expect(await token.name()).to.eq(name)
    expect(await token.symbol()).to.eq(symbol)
    expect(await token.decimals()).to.eq(decimals)
    expect(await token.totalSupply()).to.eq(totalSupply)
  })

  it('transfer', async () => {
    await expect(token.transfer(other.address, testAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, testAmount)

    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
    expect(await token.balanceOf(other.address)).to.eq(testAmount)
  })

  it('burn', async () => {
    await expect(token.burn(testAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, AddressZero, testAmount)

    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
    expect(await token.totalSupply()).to.eq(totalSupply.sub(testAmount))
  })

  it('approve', async () => {
    await expect(token.approve(other.address, testAmount))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, testAmount)

    expect(await token.allowance(wallet.address, other.address)).to.eq(testAmount)
  })

  it('approveMeta', async () => {
    const nonce = await token.nonceFor(wallet.address)
    const expiration = MaxUint256
    const digest = keccak256(
      solidityPack(
        ['bytes1', 'bytes1', 'address', 'bytes32'],
        [
          '0x19',
          '0x00',
          token.address,
          keccak256(
            solidityPack(
              ['address', 'address', 'uint256', 'uint256', 'uint256', 'uint256'],
              [wallet.address, other.address, testAmount, nonce, expiration, chainId]
            )
          )
        ]
      )
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))

    await expect(
      token
        .connect(other)
        .approveMeta(wallet.address, other.address, testAmount, nonce, expiration, v, hexlify(r), hexlify(s))
    )
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, testAmount)

    expect(await token.allowance(wallet.address, other.address)).to.eq(testAmount)
  })

  it('transferFrom', async () => {
    await token.approve(other.address, testAmount)

    await expect(token.connect(other).transferFrom(wallet.address, other.address, testAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, testAmount)

    expect(await token.allowance(wallet.address, other.address)).to.eq(0)
    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
    expect(await token.balanceOf(other.address)).to.eq(testAmount)
  })

  it('burnFrom', async () => {
    await token.approve(other.address, testAmount)

    await expect(token.connect(other).burnFrom(wallet.address, testAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, AddressZero, testAmount)

    expect(await token.allowance(wallet.address, other.address)).to.eq(0)
    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
    expect(await token.totalSupply()).to.eq(totalSupply.sub(testAmount))
    expect(await token.balanceOf(other.address)).to.eq(0)
  })

  it('transfer:fail', async () => {
    await expect(token.transfer(other.address, totalSupply.add(1))).to.be.revertedWith('SafeMath: subtraction overflow')
    await expect(token.connect(other).transfer(other.address, 1)).to.be.revertedWith('SafeMath: subtraction overflow')
  })
})
