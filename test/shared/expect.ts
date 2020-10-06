import chai, { expect } from 'chai'
import { solidity } from 'ethereum-waffle'
import { jestSnapshotPlugin } from 'mocha-chai-jest-snapshot'

chai.use(solidity)
chai.use(jestSnapshotPlugin())

export { expect }
