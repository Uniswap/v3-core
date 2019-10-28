import path from 'path'
import chai from 'chai'
import { solidity, createMockProvider, getWallets, deployContract } from 'ethereum-waffle'
import { Contract } from 'ethers'
import { AddressZero, MaxUint256 } from 'ethers/constants'
import {
  BigNumber,
  bigNumberify,
  defaultAbiCoder,
  toUtf8Bytes,
  keccak256,
  splitSignature,
  solidityPack
} from 'ethers/utils'

import ERC20 from '../build/GenericERC20.json'

chai.use(solidity)
const { expect } = chai

const decimalize = (n: number): BigNumber => bigNumberify(n).mul(bigNumberify(10).pow(18))

const name = 'Mock ERC20'
const symbol = 'MOCK'
const decimals = 18

const chainId = 1

const totalSupply = decimalize(100)
const testAmount = decimalize(10)

describe('ERC20', () => {
  const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
  const [wallet, walletTo] = getWallets(provider)
  let token: Contract

  beforeEach(async () => {
    token = await deployContract(wallet, ERC20, [name, symbol, decimals, totalSupply, chainId])
  })

  it('name, symbol, decimals, totalSupply', async () => {
    expect(await token.name()).to.eq(name)
    expect(await token.symbol()).to.eq(symbol)
    expect(await token.decimals()).to.eq(18)
    expect(await token.totalSupply()).to.eq(totalSupply)
  })

  it('transfer', async () => {
    await expect(token.transfer(walletTo.address, testAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, walletTo.address, testAmount)

    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
    expect(await token.balanceOf(walletTo.address)).to.eq(testAmount)
  })

  it('burn', async () => {
    await expect(token.burn(testAmount))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, AddressZero, testAmount)

    expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
    expect(await token.totalSupply()).to.eq(totalSupply.sub(testAmount))
  })

  it('approve', async () => {
    await expect(token.approve(walletTo.address, testAmount))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, walletTo.address, testAmount)
  })

  it('approveMeta', async () => {
    const nonce = await token.nonceFor(wallet.address)
    const expiration = MaxUint256

    const domainSeparator = keccak256(
      defaultAbiCoder.encode(
        ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
        [
          keccak256(toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
          keccak256(toUtf8Bytes(name)),
          keccak256(toUtf8Bytes('1')),
          chainId,
          token.address
        ]
      )
    )
    const approveTypehash = keccak256(
      toUtf8Bytes('Approve(address owner,address spender,uint256 value,uint256 nonce,uint256 expiration)')
    )
    const digest = keccak256(
      solidityPack(
        ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
        [
          '0x19',
          '0x01',
          domainSeparator,
          keccak256(
            defaultAbiCoder.encode(
              ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
              [approveTypehash, wallet.address, walletTo.address, testAmount, nonce, expiration]
            )
          )
        ]
      )
    )

    const { v, r, s } = splitSignature(await wallet.signMessage(digest))

    // const sig = ethUtil.ecsign(signHash(), privateKey);

    // console.log(wallet.privateKey)
    // console.log(digest)
    // console.log(v, r, s)

    await expect(token.approveMeta(wallet.address, walletTo.address, testAmount, nonce, expiration, v, r, s))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, walletTo.address, testAmount)
  })

  // it('transferFrom', async () => {
  //   await expect(token.approve(walletTo.address, testAmount))
  //     .to.emit(token, 'Approval')
  //     .withArgs(wallet.address, walletTo.address, testAmount)

  //   await expect(token.connect(walletTo).transferFrom(wallet.address, walletTo.address, testAmount))
  //     .to.emit(token, 'Transfer')
  //     .withArgs(wallet.address, walletTo.address, testAmount)

  //   expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
  //   expect(await token.balanceOf(walletTo.address)).to.eq(testAmount)
  // })

  // it('burnFrom', async () => {
  //   await expect(token.approve(walletTo.address, testAmount))
  //     .to.emit(token, 'Approval')
  //     .withArgs(wallet.address, walletTo.address, testAmount)

  //   await expect(token.connect(walletTo).transferFrom(wallet.address, walletTo.address, testAmount))
  //     .to.emit(token, 'Transfer')
  //     .withArgs(wallet.address, walletTo.address, testAmount)

  //   expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
  //   expect(await token.balanceOf(walletTo.address)).to.eq(testAmount)
  // })

  // it('approveMeta', async () => {
  //   await expect(token.approve(walletTo.address, testAmount))
  //     .to.emit(token, 'Approval')
  //     .withArgs(wallet.address, walletTo.address, testAmount)

  //   await expect(token.connect(walletTo).transferFrom(wallet.address, walletTo.address, testAmount))
  //     .to.emit(token, 'Transfer')
  //     .withArgs(wallet.address, walletTo.address, testAmount)

  //   expect(await token.balanceOf(wallet.address)).to.eq(totalSupply.sub(testAmount))
  //   expect(await token.balanceOf(walletTo.address)).to.eq(testAmount)
  // })

  // it('transfer:fail', async () => {
  //   await expect(token.transfer(walletTo.address, totalSupply.add(1))).to.be.revertedWith(
  //     'SafeMath: subtraction overflow'
  //   )

  //   await expect(token.connect(walletTo).transfer(walletTo.address, 1)).to.be.revertedWith(
  //     'SafeMath: subtraction overflow'
  //   )
  // })
})
