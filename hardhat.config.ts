import 'hardhat-typechain'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'

export default {
  networks: {
    hardhat: {
      allowUnlimitedContractSize: false,
    },
  },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 50,
      },
      debug: {
        // How to treat revert (and require) reason strings. Settings are
        // "default", "strip", "debug" and "verboseDebug".
        // "default" does not inject compiler-generated revert strings and keeps user-supplied ones.
        // "strip" removes all revert strings (if possible, i.e. if literals are used) keeping side-effects
        // "debug" injects strings for compiler-generated internal reverts, implemented for ABI encoders V1 and V2 for now.
        // "verboseDebug" even appends further information to user-supplied revert strings (not yet implemented)
        revertStrings: 'strip',
      },
      metadata: {
        // do not include the metadata hash, since this is machine dependent
        // and we want all generated code to be deterministic
        // https://docs.soliditylang.org/en/v0.7.6/metadata.html
        bytecodeHash: 'none',
      },
    },
  },
}
