// import path from 'path'
// import chai from 'chai'
// import { solidity, createMockProvider, getWallets, createFixtureLoader, deployContract } from 'ethereum-waffle'
// import { Contract } from 'ethers'
// import { BigNumber, bigNumberify } from 'ethers/utils'

// import { expandTo18Decimals, mineBlocks } from './shared/utilities'
// import { exchangeFixture, ExchangeFixture } from './shared/fixtures'

// import Oracle from '../build/Oracle.json'

// const ONE_DAY = 60 * 60 * 24

// chai.use(solidity)
// const { expect } = chai

// interface OracleSnapshot {
//   cumulativeReserves: BigNumber[]
//   blockNumber: number
//   time: number
// }

// describe('Oracle', () => {
//   const provider = createMockProvider(path.join(__dirname, '..', 'waffle.json'))
//   const [wallet] = getWallets(provider)
//   const loadFixture = createFixtureLoader(provider, [wallet])

//   let token0: Contract
//   let token1: Contract
//   let exchange: Contract
//   let oracle: Contract
//   beforeEach(async () => {
//     const { token0: _token0, token1: _token1, exchange: _exchange } = (await loadFixture(
//       exchangeFixture as any
//     )) as ExchangeFixture
//     token0 = _token0
//     token1 = _token1
//     exchange = _exchange
//     oracle = await deployContract(wallet, Oracle, [exchange.address])
//   })

//   async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
//     await token0.transfer(exchange.address, token0Amount)
//     await token1.transfer(exchange.address, token1Amount)
//     await exchange.connect(wallet).mintLiquidity(wallet.address)
//   }

//   async function swap(inputToken: Contract, amount: BigNumber) {
//     const token0 = await exchange.token0()
//     const reserves = await exchange.getReserves()

//     const inputReserve = inputToken.address === token0 ? reserves[0] : reserves[1]
//     const outputReserve = inputToken.address === token0 ? reserves[1] : reserves[0]
//     const outputAmount = await exchange.getAmountOutput(amount, inputReserve, outputReserve)

//     await inputToken.transfer(exchange.address, amount)
//     await exchange.connect(wallet).swap(inputToken.address, wallet.address)

//     return outputAmount
//   }

//   it('exchange, getCurrentPrice', async () => {
//     expect(await oracle.exchange()).to.eq(exchange.address)
//     expect(await oracle.getCurrentPrice()).to.deep.eq([0, 0].map(n => bigNumberify(n)))
//   })

//   async function getOracleSnapshot(): Promise<OracleSnapshot> {
//     const cumulativeReserves = await exchange.getReservesCumulative()
//     const blockNumber = await provider.getBlockNumber()
//     const time = (await provider.getBlock(blockNumber)).timestamp

//     return {
//       cumulativeReserves,
//       blockNumber,
//       time
//     }
//   }

//   // function getExpectedOraclePrice(
//   //   preSnapshot: OracleSnapshot,
//   //   postSnapshot: OracleSnapshot,
//   //   oldPrice: BigNumber[],
//   //   elapsedTime: number
//   // ) {
//   //   return 1
//   // }

//   // it('updateCurrentPrice', async () => {
//   //   const token0Amount = expandTo18Decimals(5)
//   //   const token1Amount = expandTo18Decimals(10)
//   //   await addLiquidity(token0Amount, token1Amount)

//   //   await oracle.connect(wallet).initialize()
//   //   expect(await oracle.getCurrentPrice()).to.deep.eq([0, 0].map(n => bigNumberify(n)))

//   //   await oracle.connect(wallet).activate()
//   //   expect(await oracle.getCurrentPrice()).to.deep.eq([token0Amount, token1Amount])

//   //   const preSwapSnapshot = await getOracleSnapshot()

//   //   const swapAmount = expandTo18Decimals(5)
//   //   const expectedToken1Amount = await swap(token0, swapAmount)
//   //   const postSwapToken0Amount = token0Amount.add(swapAmount)
//   //   const postSwapToken1Amount = token1Amount.sub(expectedToken1Amount)

//   //   const postSwapSnapshot = await getOracleSnapshot()

//   //   const elapsedBlocks = postSwapSnapshot.blockNumber - preSwapSnapshot.blockNumber
//   //   expect(elapsedBlocks).to.eq(2)

//   //   await oracle.connect(wallet).update()

//   //   const elapsedTime = postSwapSnapshot.time - preSwapSnapshot.time
//   //   if (elapsedTime === 0) {
//   //     expect(await oracle.getCurrentPrice()).to.deep.eq([token0Amount, token1Amount])
//   //   } else {
//   //     console.log('uh oh!')
//   //     // expect(await oracle.getCurrentPrice()).to.deep.eq([token0Amount, token1Amount])
//   //   }

//   //   // console.log((await oracle.getCurrentPrice()).map((p: BigNumber): string => p.toString()))

//   //   // await mineBlocks(provider, 1, timePost + 60 * 60 * (24 / 2))
//   //   // await oracle.connect(wallet).update()
//   // })
// })
