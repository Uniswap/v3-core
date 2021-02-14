import { readFileSync, readdirSync, existsSync, mkdirSync, writeFileSync } from 'fs'
import { resolve } from 'path'

const artifactsFolder = resolve(__dirname, '..', 'artifacts')
const buildInfoFolder = resolve(artifactsFolder, 'build-info')
const docsOutputFolder = resolve(artifactsFolder, 'docs')
const docsFile = resolve(docsOutputFolder, 'docs.json')
const contents = readdirSync(buildInfoFolder)
if (contents.length !== 1) throw new Error('unexpected contents')

const buildOutput = JSON.parse(readFileSync(resolve(buildInfoFolder, contents[0]), { encoding: 'utf8' }))

const FILENAMES_DOCS_GENERATE = ['contracts/UniswapV3Pool.sol', 'contracts/UniswapV3Factory.sol']

const output = Object.keys(buildOutput.output.contracts).reduce((results, fileName) => {
  const contractsInFile = Object.keys(buildOutput.output.contracts[fileName])
  if (FILENAMES_DOCS_GENERATE.indexOf(fileName) === -1 && !fileName.startsWith('contracts/interfaces/')) return results

  return {
    ...results,
    ...contractsInFile.reduce((outputs, contractName) => {
      const contract = buildOutput.output.contracts[fileName][contractName]
      const { devdoc, userdoc } = contract
      return {
        ...outputs,
        [contractName]: {
          userdoc,
          devdoc,
        },
      }
    }, {}),
  }
}, {})

if (!existsSync(docsOutputFolder)) mkdirSync(docsOutputFolder)

writeFileSync(docsFile, JSON.stringify(output, null, 2), { encoding: 'utf8' })
