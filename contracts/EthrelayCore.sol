// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4 <0.9.0;

import "./MerklePatriciaProof.sol";

abstract contract EthashInterface {
    function verifyPoW(uint blockNumber, bytes32 rlpHeaderHashWithoutNonce, uint nonce, uint difficulty,
        uint[] calldata dataSetLookup, uint[] calldata witnessForLookup) external view virtual returns (uint, uint);
}

/// @title EthrelayCore: A contract enabling cross-blockchain verifications of transactions,
///        receipts and states on a destination blockchain of a source blockchain
/// @author Marten Sigwart, Philipp Frauenthaler, Leonhard Esterbauer, Markus Levonyak
/// @notice You can use this contract for submitting new block headers, disputing already submitted block headers and
///         for verifying Merkle Patricia proofs of transactions, receipts and states
contract EthrelayCore {

    using RLPReader for *;

    // the verification- and dispute-process takes a long time, so it may not be possible to verify and additionally
    // dispute the block within 5mins if a disputer don't have a generated DAG on the hard disk. to solve this
    // quickly, make the process faster or increase the lock period to get enough time for clients to dispute
    uint16 constant LOCK_PERIOD_IN_MIN = 5 minutes;
    uint8 constant ALLOWED_FUTURE_BLOCK_TIME = 15 seconds;
    uint8 constant MAX_EXTRA_DATA_SIZE = 32;
    uint8 constant REQU_SUCEEDING_BLOCKS = 3;
    uint16 constant MIN_GAS_LIMIT = 5000;
    int64 constant GAS_LIMIT_BOUND_DIVISOR = 1024;
    uint constant MAX_GAS_LIMIT = 2**63-1;
    bytes32 constant EMPTY_UNCLE_HASH = hex"1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347";

    // pointer to the ethash-contract that holds functions for calculating and verifying proof of work (keccak) in a contract
    EthashInterface ethashContract;

    struct MetaInfo {
        uint64 iterableIndex;       // index at which the block header is/was stored in the iterable endpoints array
        uint64 forkId;              // every branch gets a branchId/forkId, stored to speed up block-search/isPartOfMainChain-reqeuests etc.
        uint64 lockedUntil;         // timestamp until which it is possible to dispute a given block
        bytes32 latestFork;         // contains the hash of the latest node where the current fork branched off
        address submitter;          // address of the submitter of the block, stored for incentive and punishment reasons
        bytes32[] successors;       // in case of forks a blockchain can have multiple successors
    }

    // for proving inclusion etc. only the header and some meta-info is stored, if one want to make further operations
    // on data in the FullHeader, one has to go back to the submit-transaction of this block and search for the event
    // why: the FullHeader space consumption is high and emitting it once is cheaper than save it in the state
    struct Header {
        // uint24 first and uint232 second to pack variables in 1 uint256 variable
        uint24 blockNumber;
        uint232 totalDifficulty;
        bytes32 hash;
        MetaInfo meta;
    }

    // FullHeader is needed when a block is submitted, but will never be saved in state to reduce costs
    struct FullHeader {
        bytes32 parent;
        bytes32 uncleHash;
        bytes32 stateRoot;
        bytes32 transactionsRoot;
        bytes32 receiptsRoot;
        uint blockNumber;
        uint gasLimit;
        uint gasUsed;
        bytes32 rlpHeaderHashWithoutNonce;   // sha3 hash of the header without nonce and mix fields, placed here because of pointer-position in byte-arrays
        uint timestamp;                      // block timestamp is needed for difficulty calculation
        uint nonce;                          // blockNumber, rlpHeaderHashWithoutNonce and nonce are needed for verifying PoW
        uint difficulty;
        bytes extraData;
    }

    uint64 maxForkId = 0;                           // current fork-id, is incrementing
    bytes32 longestChainEndpoint;                   // saves the hash of the block with the highest blockNr. (most PoW work)
    bytes32 genesisBlockHash;                       // saves the hash of the genesis block the contract was deployed with
                                                    // maybe the saving of the genesis block could also be achieved with events in the
                                                    // constructor that gives very small savings
    mapping (bytes32 => Header) private headers;    // holds all block in a hashmap, key=blockhash, value=reduced block headers with metadata
    bytes32[] iterableEndpoints;                    // holds endpoints of all forks of the PoW-tree to speed up submission, deletion etc.

    // here, the consideration was to use indexes as these are much faster for searching in the blockchain
    // the counterpart is the higher gas, a index log costs (very cheap), but as the content of the submit
    // block is only important to participants in the time of the lock period like disputers, we can simply
    // do a linear backwards search and find the event in the last e.g. 10mins, this is a reasonable amount
    // of time of block search a client can handle easily and fast
    event NewBlock(bytes32 blockHash);

    // initialize the contract with a rlpHeader of the wanted genesis block, the actual totalDifficulty at this block and
    // the deployed ethhashContractAddress to verify PoW of this header, the contract creator needs to make sure that these
    // values represent a valid block of the tracked blockchain
    constructor (bytes memory _rlpHeader, uint totalDifficulty, address _ethashContractAddr) {
        bytes32 newBlockHash = keccak256(_rlpHeader);

        FullHeader memory parsedHeader = parseRlpEncodedHeader(_rlpHeader);
        Header memory newHeader;

        newHeader.hash = newBlockHash;
        newHeader.blockNumber = uint24(parsedHeader.blockNumber);
        newHeader.totalDifficulty = uint232(totalDifficulty);
        newHeader.meta.forkId = maxForkId;  // the first block is no fork (forkId = 0)
        iterableEndpoints.push(newBlockHash);
        newHeader.meta.iterableIndex = uint64(iterableEndpoints.length - 1);    // the first block is also an endpoint
        newHeader.meta.lockedUntil = uint64(block.timestamp);   // the first block does not need a confirmation period

        headers[newBlockHash] = newHeader;

        longestChainEndpoint = newBlockHash;    // the first block is also the longest chain/fork at the moment

        ethashContract = EthashInterface(_ethashContractAddr);

        genesisBlockHash = newBlockHash;

        emit NewBlock(newBlockHash);
    }

    function getLongestChainEndpoint() public view returns (bytes32 hash) {
        return longestChainEndpoint;
    }

    function getGenesisBlockHash() public view returns (bytes32 hash) {
        return genesisBlockHash;
    }

    function getHeader(bytes32 blockHash) public view returns (bytes32 hash, uint blockNumber, uint totalDifficulty) {
        Header storage header = headers[blockHash]; // only a storage-pointer
        return (
            header.hash,
            header.blockNumber,
            header.totalDifficulty
        );
    }

    function getHeaderMetaInfo(bytes32 blockHash) internal view returns (
        bytes32[] memory successors, uint forkId, uint iterableIndex, bytes32 latestFork, uint lockedUntil,
        address submitter
    ) {
        Header storage header = headers[blockHash];
        return (
            header.meta.successors,
            header.meta.forkId,
            header.meta.iterableIndex,
            header.meta.latestFork,
            header.meta.lockedUntil,
            header.meta.submitter
        );
    }

    function getLockedUntil(bytes32 blockHash) internal view returns (uint) {
        return headers[blockHash].meta.lockedUntil;
    }

    function getNoOfForks() internal view returns (uint) {
        return iterableEndpoints.length;
    }

    // @dev Returns the block hash of the endpoint at the specified index
    function getBlockHashOfEndpoint(uint index) internal view returns (bytes32) {
        return iterableEndpoints[index];
    }

    function isHeaderStored(bytes32 hash) public view returns (bool) {
        return headers[hash].blockNumber != 0;
    }

    // there is one problem here that is necessary to tell the participants: if multiple participants are
    // submitting the same block, they all have to pay the fees for the transaction, but only one block is
    // accepted and the other submit-actions from other participants are simply wasted, this is a risk for
    // the users to pay and pay the fees for transactions, but get never back some reward as they are not
    // able to submit new blocks if they e.g. have a high latency to the next node (anyways, this should
    // be distributed around the world if you don't know where the next block is being mined, so everyone
    // may has at least equally chances)
    // a possible solution to this problem is to create another timespan in that all the submits are
    // counted and after that timespan all the submitters get a fraction ot the reward, this is like the
    // uncle-reward in the ethereum approach

    // another problem with submitHeader is the submission of very new blocks from the source blockchain
    // that are not very likely to stay in the longest chain, here also the participants have to choose
    // if they are waiting for "solid" blocks and other may submit the header before, or submit all new
    // blocks immediately to get the rewards more likely but accept the risk of submitting fork-blocks
    // that only cost some transaction fee on the destination blockchain

    /// @dev Accepts an RLP encoded header. The provided header is parsed and its hash along with some meta data is stored.
    function submitHeader(bytes memory _rlpHeader, address submitter) internal returns (bytes32) {
        Header memory newHeader;

        // calculate block hash of rlp header
        bytes32 blockHash = keccak256(_rlpHeader);

        // check if header has not been submitted before
        require(!isHeaderStored(blockHash), "block already exists");

        // read metadata from rlp encoded header
        bytes32 decodedParent;
        uint decodedBlockNumber;
        uint decodedDifficulty;
        (decodedParent, decodedBlockNumber, decodedDifficulty) = getParentBlockNumberDiff(_rlpHeader);

        // check if parent exists
        require(isHeaderStored(decodedParent), "parent does not exist");

        // add block to successors of parent
        Header storage parentHeader = headers[decodedParent];
        parentHeader.meta.successors.push(blockHash);

        newHeader.hash = blockHash;
        newHeader.blockNumber = uint24(decodedBlockNumber);
        newHeader.totalDifficulty = uint232(parentHeader.totalDifficulty + decodedDifficulty);
        newHeader.meta.lockedUntil = uint64(block.timestamp + LOCK_PERIOD_IN_MIN);
        newHeader.meta.submitter = submitter;

        // check if parent is an endpoint
        if (iterableEndpoints.length > parentHeader.meta.iterableIndex && iterableEndpoints[parentHeader.meta.iterableIndex] == decodedParent) {
            // parentHeader is an endpoint (and no fork) -> replace parentHeader in endpoints by new header (since new header becomes new endpoint)
            newHeader.meta.forkId = parentHeader.meta.forkId;
            iterableEndpoints[parentHeader.meta.iterableIndex] = newHeader.hash;
            newHeader.meta.iterableIndex = parentHeader.meta.iterableIndex;
            delete parentHeader.meta.iterableIndex;
            newHeader.meta.latestFork = parentHeader.meta.latestFork;
        } else {
            // parentHeader is forked
            maxForkId += 1;
            newHeader.meta.forkId = maxForkId;
            iterableEndpoints.push(newHeader.hash);
            newHeader.meta.iterableIndex = uint64(iterableEndpoints.length - 1);
            newHeader.meta.latestFork = decodedParent;

            if (parentHeader.meta.successors.length == 2) {
                // a new fork was created, so we set the latest fork of the original branch to the newly created fork
                // this has to be done only the first time a fork is created and updates the whole chain from parent header
                // to every successor having exactly one successor
                setLatestForkAtSuccessors(headers[parentHeader.meta.successors[0]], decodedParent);
            }
        }

        // if total difficulty is higher, a new longest chain came up
        if (newHeader.totalDifficulty > headers[longestChainEndpoint].totalDifficulty) {
            longestChainEndpoint = blockHash;
        }

        // save header, important: make sure to persist the header only AFTER all property changes
        headers[newHeader.hash] = newHeader;

        return newHeader.hash;
    }

    // the worst case is to fire an expensive dispute event on a valid block, this is indeed possible if a "attacker"
    // is able to relay a valid block not existing on the source blockchain and participants only check for existence on
    // the source blockchain, but that case is very unlikely because it means the attacker is able to produce blocks
    // in a faster way than the source blockchain produces new blocks, workaround: get the rlpHeader from the submit
    // -transaction of new blocks and check the header locally on the client before executing a public dispute

    // another case is the parallelism of the dispute call: this is similar to the special case when two participants
    // are submitting the same block, only one gets the dispute-reward, but both pay for the expensive dispute and
    // validation process

    event DisputeBlock(uint returnCode);
    event PoWValidationResult(uint returnCode, uint errorInfo);
    /// @dev If a client is convinced that a certain block header is invalid, it can call this function which validates
    ///      whether enough PoW has been carried out.
    /// @param rlpHeader the encoded version of the block header to dispute
    /// @param rlpParent the encoded version of the block header's parent
    /// @param dataSetLookup contains elements of the DAG needed for the PoW verification
    /// @param witnessForLookup needed for verifying the dataSetLookup
    /// @return A list of addresses belonging to the submitters of illegal blocks
    function disputeBlock(bytes calldata rlpHeader, bytes memory rlpParent, uint[] memory dataSetLookup,
                          uint[] memory witnessForLookup) internal returns (address[] memory) {
        // Currently, once the dispute period is over and the block is unlocked we accept it as valid.
        // In that case, no validation is carried out anymore.

        // outsourcing verifying of validity and PoW because solidity encountered a stack too deep exception before
        uint returnCode = verifyValidityAndPoW(rlpHeader, rlpParent, dataSetLookup, witnessForLookup);

        address[] memory submittersToPunish = new address[](0);

        if (returnCode != 0) {
            submittersToPunish = removeBranch(keccak256(rlpHeader), headers[keccak256(rlpParent)]);
        }

        emit DisputeBlock(returnCode);

        return submittersToPunish;
    }

    // helper function to not get a stack to deep exception
    function verifyValidityAndPoW(bytes calldata rlpHeader, bytes memory rlpParent, uint[] memory dataSetLookup, uint[] memory witnessForLookup) private returns (uint) {
        uint returnCode;
        uint24 blockNumber;
        uint nonce;
        uint difficulty;

        // verify validity of header and parent
        (returnCode, blockNumber, nonce, difficulty) = verifyValidity(rlpHeader, rlpParent);

        // if return code is 0, the block and it's parent seem to be valid
        // next check the ethash PoW algorithm
        if (returnCode == 0) {
            // header validation without checking Ethash was successful -> verify Ethash
            uint errorInfo;

            (returnCode, errorInfo) = ethashContract.verifyPoW(blockNumber, getRlpHeaderHashWithoutNonce(rlpHeader),
                nonce, difficulty, dataSetLookup, witnessForLookup);

            emit PoWValidationResult(returnCode, errorInfo);
        }

        return returnCode;
    }

    // initially this logic was part of the disputeBlock method, but as the solidity compiler failed for
    // such big logic blocks the logic was split in 2 sub methods to save stack space
    // so maybe this necessary call can be enhanced to use a little less gas integrating in the upper method while
    // preserving the logic, e.g. the storedParent is read read from storage 2 times, maybe pass as argument if cheaper,
    // this should not cause too much cost increase
    function verifyValidity(bytes memory rlpHeader, bytes memory rlpParent) private view returns (uint, uint24, uint, uint) {
        bytes32 headerHash = keccak256(rlpHeader);
        bytes32 parentHash = keccak256(rlpParent);

        require(isHeaderStored(headerHash), "provided header does not exist");
        require(isHeaderStored(parentHash), "provided parent does not exist");
        require(!isUnlocked(headerHash), "dispute period is expired");

        Header storage storedHeader = headers[headerHash];
        Header storage storedParent = headers[parentHash];

        require(isHeaderSuccessorOfParent(storedHeader, storedParent), "stored parent is not a predecessor of stored header within Ethrelay");

        FullHeader memory providedHeader = parseRlpEncodedHeader(rlpHeader);
        FullHeader memory providedParent = parseRlpEncodedHeader(rlpParent);

        require(providedHeader.parent == parentHash, "provided header's parent does not match with provided parent' hash");

        return (checkHeaderValidity(providedHeader, providedParent), storedHeader.blockNumber, providedHeader.nonce, providedHeader.difficulty);
    }

    function isHeaderSuccessorOfParent(Header memory header, Header memory parent) private pure returns (bool) {
        for (uint i = 0; i < parent.meta.successors.length; i++) {
            bytes32 successor = parent.meta.successors[i];

            if (successor == header.hash) {
                return true;
            }
        }

        return false;
    }

    /// @dev Verifies the existence of a transaction, receipt or state ('rlpEncodedValue') within a certain block ('blockHash').
    /// @param blockHash the hash of the block that contains the Merkle root hash
    /// @param noOfConfirmations the required number of succeeding blocks needed for a block to be considered as confirmed
    /// @param rlpEncodedValue the value of the Merkle Patricia trie (e.g. transaction, receipt, state) in RLP format
    /// @param path the path (key) in the trie indicating the way starting at the root node and ending at the value (e.g. transaction)
    /// @param rlpEncodedNodes an RLP encoded list of nodes of the Merkle branch, first element is the root node, last element the value
    /// @param merkleRootHash the hash of the root node of the Merkle Patricia trie
    /// @return 0: verification was successful
    ///         1: block is confirmed and unlocked, but the Merkle proof was invalid
    //
    // The verification follows the following steps:
    //     1. Verify that the given block is part of the longest Proof of Work chain. this suffices when used in combination with noOfConfirmations and lockedUntil params
    //     2. Verify that the block is unlocked and has been confirmed by at least n succeeding unlocked blocks ('noOfConfirmations')
    //     3. Verify the Merkle Patricia proof of the given block
    //
    // In case we have to check whether enough block confirmations occurred
    // starting from the requested block ('blockHash'), we go to the latest
    // unlocked block on the longest chain path (could be the requested block itself)
    // and count the number of confirmations (i.e. the number of unlocked blocks),
    // starting from the latest unlocked block along the longest chain path.
    // The verification only works, if at least 1 (altruistic) participant submits blocks from the source blockchain to retain the correct longest chain
    // and 1 (altruistic) participant disputes illegal blocks to prevent fake/invalid blocks building the longest chain (this can be the same participant)
    function verifyMerkleProof(bytes32 blockHash, uint8 noOfConfirmations, bytes memory rlpEncodedValue,
        bytes memory path, bytes memory rlpEncodedNodes, bytes32 merkleRootHash) internal view returns (uint8) {

        require(isHeaderStored(blockHash), "block does not exist");

        (bool isPartOfLongestPoWCFork, bytes32 confirmationStart) = isBlockPartOfFork(blockHash, longestChainEndpoint);
        require(isPartOfLongestPoWCFork, "block is not part of the longest PoW chain");

        if (headers[confirmationStart].blockNumber <= headers[blockHash].blockNumber + noOfConfirmations) {
            noOfConfirmations = noOfConfirmations - uint8(headers[confirmationStart].blockNumber - headers[blockHash].blockNumber);
            bool unlockedAndConfirmed = hasEnoughConfirmations(confirmationStart, noOfConfirmations);
            require(unlockedAndConfirmed, "block is locked or not confirmed by enough blocks");
        }

        if (MerklePatriciaProof.verify(rlpEncodedValue, path, rlpEncodedNodes, merkleRootHash) > 0) {
            return 1;
        }

        return 0;
    }

    function isBlockConfirmed(bytes32 blockHash, uint8 noOfConfirmations) internal view returns (bool) {

        if (isHeaderStored(blockHash) == false) {
            return false;
        }

        (bool isPartOfLongestPoWCFork, bytes32 confirmationStart) = isBlockPartOfFork(blockHash, longestChainEndpoint);
        if (isPartOfLongestPoWCFork == false) {
            return false;
        }

        if (headers[confirmationStart].blockNumber <= headers[blockHash].blockNumber + noOfConfirmations) {
            noOfConfirmations = noOfConfirmations - uint8(headers[confirmationStart].blockNumber - headers[blockHash].blockNumber);
            bool unlockedAndConfirmed = hasEnoughConfirmations(confirmationStart, noOfConfirmations);
            if (unlockedAndConfirmed == false) {
                return false;
            }
        }

        return true;
    }

    function isBlockPartOfFork(bytes32 blockHash, bytes32 forkEndpoint) private view returns (bool, bytes32) {
        bytes32 current = forkEndpoint;
        bytes32 confirmationStartHeader;    // the hash from where to start the confirmation count in case the requested block header is part of the longest chain
        uint lastForkId;

        // Current is still the endpoint
        // if the endpoint is already unlocked we need to start the confirmation verification from the endpoint
        if (isUnlocked(current)) {
            confirmationStartHeader = current;
        }

        while (headers[current].meta.forkId > headers[blockHash].meta.forkId) {
            // go to next fork point but remember last fork id
            lastForkId = headers[current].meta.forkId;
            current = headers[current].meta.latestFork;

            // set confirmationStartHeader only if it has not been set before
            if (confirmationStartHeader == 0) {
                if (isUnlocked(current)) {
                    confirmationStartHeader = getSuccessorByForkId(current, lastForkId);
                }
            }
        }

        if (headers[current].meta.forkId < headers[blockHash].meta.forkId) {
            return (false, confirmationStartHeader);   // the requested block is NOT part of the longest chain
        }

        if (headers[current].blockNumber < headers[blockHash].blockNumber) {
            // current and the requested block are on a fork with the same fork id
            // however, the requested block comes after the fork point (current), so the requested block cannot be part of the longest chain
            return (false, confirmationStartHeader);
        }

        // if no earlier block header has been found from where to start the confirmation verification,
        // we start the verification from the requested block header
        if (confirmationStartHeader == 0) {
            confirmationStartHeader = blockHash;
        }

        return (true, confirmationStartHeader);
    }

    function isUnlocked(bytes32 blockHash) internal view returns (bool) {
        return headers[blockHash].meta.lockedUntil < block.timestamp;
    }

    function getSuccessorByForkId(bytes32 blockHash, uint forkId) private view returns (bytes32) {
        for (uint i = 0; i < headers[blockHash].meta.successors.length; i++) {
            bytes32 successor = headers[blockHash].meta.successors[i];

            if (headers[successor].meta.forkId == forkId) {
                return successor;
            }
        }

        return blockHash;
    }

    // @dev Checks whether a block has enough succeeding blocks that are unlocked (dispute period is over).
    // Note: The caller has to make sure that this method is only called for paths where the required number of
    // confirmed blocks does not go beyond forks, i.e., each block has to have a clear successor.
    // If a block is a fork, i.e., has more than one successor and requires more than 0 confirmations
    // the method returns false, which may or may not represent the true state of the system.
    function hasEnoughConfirmations(bytes32 start, uint8 noOfConfirmations) private view returns (bool) {
        if (!isUnlocked(start)) {
            return false;   // --> block is still locked and can therefore not be confirmed
        }

        if (noOfConfirmations == 0) {
            return true;    // --> block is unlocked and no more confirmations are required
        }

        if (headers[start].meta.successors.length == 0) {
            // More confirmations are required but block has no more successors.
            return false;
        }

        return hasEnoughConfirmations(headers[start].meta.successors[0], noOfConfirmations - 1);
    }

    function setLatestForkAtSuccessors(Header storage header, bytes32 latestFork) private {
        if (header.meta.latestFork == latestFork) {
            // latest fork has already been set
            return;
        }

        header.meta.latestFork = latestFork;

        if (header.meta.successors.length == 1) {
            setLatestForkAtSuccessors(headers[header.meta.successors[0]], latestFork);
        }
    }

    function setLatestForkAndForkIdAtSuccessors(Header storage header, bytes32 latestFork, uint64 forkId) private {
        if (header.meta.latestFork == latestFork) {
            // latest fork has already been set
            return;
        }

        header.meta.latestFork = latestFork;
        header.meta.forkId = forkId;

        if (header.meta.successors.length == 1) {
            setLatestForkAndForkIdAtSuccessors(headers[header.meta.successors[0]], latestFork, forkId);
        }
    }

    event RemoveBranch(bytes32 root);

    function removeBranch(bytes32 rootHash, Header storage parentHeader) private returns (address[] memory) {
        address[] memory submitters = pruneBranch(rootHash, 0);

        if (parentHeader.meta.successors.length == 1) {
            // parentHeader has only one successor --> parentHeader will be an endpoint after pruning
            iterableEndpoints.push(parentHeader.hash);
            parentHeader.meta.iterableIndex = uint64(iterableEndpoints.length - 1);
        }

        // remove root (which will be pruned) from the parent's successor list
        for (uint i=0; i < parentHeader.meta.successors.length; i++) {
            if (parentHeader.meta.successors[i] == rootHash) {

                // overwrite root with last successor and delete last successor
                parentHeader.meta.successors[i] = parentHeader.meta.successors[parentHeader.meta.successors.length - 1];
                parentHeader.meta.successors.pop();

                // we remove at most one element, if this is done we can break to save gas
                break;
            }
        }

        if (parentHeader.meta.successors.length == 1) {
            // only one successor left after pruning -> parent is no longer a fork junction
            setLatestForkAndForkIdAtSuccessors(headers[parentHeader.meta.successors[0]], parentHeader.meta.latestFork, parentHeader.meta.forkId);
        }

        // find new longest chain endpoint
        longestChainEndpoint = iterableEndpoints[0];
        for (uint i=1; i<iterableEndpoints.length; i++) {
            if (headers[iterableEndpoints[i]].totalDifficulty > headers[longestChainEndpoint].totalDifficulty) {
                longestChainEndpoint = iterableEndpoints[i];
            }
        }

        emit RemoveBranch(rootHash);

        return submitters;
    }

    function pruneBranch(bytes32 root, uint counter) private returns (address[] memory) {
        Header storage rootHeader = headers[root];
        address[] memory submitters;

        counter += 1;

        if (rootHeader.meta.successors.length > 1) {
            address[] memory aggregatedSubmitters = new address[](0);

            for (uint i = 0; i < rootHeader.meta.successors.length; i++) {
                address[] memory submittersOfBranch = pruneBranch(rootHeader.meta.successors[i], 0);

                aggregatedSubmitters = combineArrays(aggregatedSubmitters, submittersOfBranch);
            }

            submitters = copyArrays(new address[](aggregatedSubmitters.length + counter), aggregatedSubmitters, counter);

        }

        if (rootHeader.meta.successors.length == 1) {
            submitters = pruneBranch(rootHeader.meta.successors[0], counter);
        }

        if (iterableEndpoints.length > rootHeader.meta.iterableIndex && iterableEndpoints[rootHeader.meta.iterableIndex] == root) {
            // root is an endpoint --> delete root in endpoints array, since root will be deleted and thus can no longer be an endpoint
            bytes32 lastIterableElement = iterableEndpoints[iterableEndpoints.length - 1];

            iterableEndpoints[rootHeader.meta.iterableIndex] = lastIterableElement;
            iterableEndpoints.pop();

            headers[lastIterableElement].meta.iterableIndex = rootHeader.meta.iterableIndex;

            submitters = new address[](counter);
        }

        submitters[counter-1] = headers[root].meta.submitter;

        delete headers[root];

        return submitters;
    }

    function copyArrays(address[] memory dest, address[] memory src, uint startIndex) private pure returns (address[] memory) {
        require(dest.length - startIndex >= src.length);

        uint j = startIndex;

        for (uint i = 0; i < src.length; i++) {
            dest[j] = src[i];
            j++;
        }

        return dest;
    }

    function combineArrays(address[] memory arr1, address[] memory arr2) private pure returns (address[] memory) {
        address[] memory resultArr = new address[](arr1.length + arr2.length);
        uint i = 0;

        // copy arr1 to resultArr
        for (; i < arr1.length; i++) {
            resultArr[i] = arr1[i];
        }

        // copy arr2 to resultArr
        for (uint j = 0; j < arr2.length; j++) {
            resultArr[i] = arr2[j];
            i++;
        }

        return resultArr;
    }

    function parseRlpEncodedHeader(bytes memory rlpHeader) private pure returns (FullHeader memory) {
        FullHeader memory header;

        RLPReader.Iterator memory it = rlpHeader.toRlpItem().iterator();
        uint idx;
        while(it.hasNext()) {
            if( idx == 0 ) header.parent = bytes32(it.next().toUint());
            else if ( idx == 1 ) header.uncleHash = bytes32(it.next().toUint());
            else if ( idx == 3 ) header.stateRoot = bytes32(it.next().toUint());
            else if ( idx == 4 ) header.transactionsRoot = bytes32(it.next().toUint());
            else if ( idx == 5 ) header.receiptsRoot = bytes32(it.next().toUint());
            else if ( idx == 7 ) header.difficulty = it.next().toUint();
            else if ( idx == 8 ) header.blockNumber = it.next().toUint();
            else if ( idx == 9 ) header.gasLimit = it.next().toUint();
            else if ( idx == 10 ) header.gasUsed = it.next().toUint();
            else if ( idx == 11 ) header.timestamp = it.next().toUint();
            else if ( idx == 12 ) header.extraData = it.next().toBytes();
            else if ( idx == 14 ) header.nonce = it.next().toUint();
            else it.next();

            idx++;
        }

        return header;
    }

    function getRlpHeaderHashWithoutNonce(bytes calldata rlpHeader) private pure returns (bytes32) {

        RLPReader.Iterator memory it = rlpHeader.toRlpItem().iterator();
        uint byteIdx = 3;  // RLP list starts with list prefix and the length of the payload
        uint elementIdx;
        uint startCut;
        uint endCut;

        while(it.hasNext()) {
            if (elementIdx == 13) {
                startCut = byteIdx;
            }

            RLPReader.RLPItem memory cur = it.next();
            byteIdx += cur.len;

            if (elementIdx == 14) {
                endCut = byteIdx;
                break;
            }

            elementIdx++;
        }

        bytes memory truncatedRlpHeader = bytes.concat(rlpHeader[:startCut], rlpHeader[endCut:]);
        uint16 rlpHeaderWithoutNonceLength = uint16(
            rlpHeader.length        // Length of original RLP header
            - 3                     // RLP List prefix bytes (0xf9 + two bytes for payload length)
            - (endCut - startCut)   // Length of MixDigest and Nonce fields
        );

        bytes2 headerLengthBytes = bytes2(rlpHeaderWithoutNonceLength);

        // Update payload length
        truncatedRlpHeader[1] = headerLengthBytes[0];
        truncatedRlpHeader[2] = headerLengthBytes[1];

        return keccak256(truncatedRlpHeader);
    }

    function getTxRoot(bytes memory rlpHeader) internal pure returns (bytes32) {
        RLPReader.Iterator memory it = rlpHeader.toRlpItem().iterator();
        uint idx;
        while(it.hasNext()) {
            if ( idx == 4 ) return bytes32(it.next().toUint());
            else it.next();

            idx++;
        }

        return 0;
    }

    function getStateRoot(bytes memory rlpHeader) internal pure returns (bytes32) {
        RLPReader.Iterator memory it = rlpHeader.toRlpItem().iterator();
        uint idx;
        while(it.hasNext()) {
            if ( idx == 3 ) return bytes32(it.next().toUint());
            else it.next();

            idx++;
        }

        return 0;
    }

    function getReceiptsRoot(bytes memory rlpHeader) internal pure returns (bytes32) {
        RLPReader.Iterator memory it = rlpHeader.toRlpItem().iterator();
        uint idx;
        while(it.hasNext()) {
            if ( idx == 5 ) return bytes32(it.next().toUint());
            else it.next();

            idx++;
        }

        return 0;
    }

    function getParentBlockNumberDiff(bytes memory rlpHeader) internal pure returns (bytes32, uint, uint) {
        uint idx;
        bytes32 parent;
        uint blockNumber;
        uint difficulty;
        RLPReader.Iterator memory it = rlpHeader.toRlpItem().iterator();

        while(it.hasNext()) {
            if( idx == 0 ) parent = bytes32(it.next().toUint());
            else if ( idx == 7 ) difficulty = it.next().toUint();
            else if ( idx == 8 ) blockNumber = it.next().toUint();
            else it.next();

            idx++;
        }

        return (parent, blockNumber, difficulty);
    }

    function copy(bytes memory sourceArray, uint newLength) private pure returns (bytes memory) {
        uint newArraySize = newLength;

        if (newArraySize > sourceArray.length) {
            newArraySize = sourceArray.length;
        }

        bytes memory newArray = new bytes(newArraySize);

        for(uint i = 0; i < newArraySize; i++){
            newArray[i] = sourceArray[i];
        }

        return newArray;
    }

    // @dev Validates the fields of a block header without validating Ethash.
    // The validation largely follows the header validation of the geth implementation:
    // https://github.com/ethereum/go-ethereum/blob/aa6005b469fdd1aa7a95f501ce87908011f43159/consensus/ethash/consensus.go#L241
    function checkHeaderValidity(FullHeader memory header, FullHeader memory parent) private view returns (uint) {
        // check extraData size
        if (header.extraData.length > MAX_EXTRA_DATA_SIZE) return 3;

        // check timestamp not in the future
        if (header.timestamp > block.timestamp + ALLOWED_FUTURE_BLOCK_TIME) return 5;

        // validate gas limit
        if (header.gasLimit > MAX_GAS_LIMIT) return 8; // verify that the gas limit is <= 2^63-1
        if (header.gasLimit < MIN_GAS_LIMIT) return 9; // verify that the gas limit is >= 5000

        // if there are already endpoints available, perform additional checks
        // else it is the genesis block and has no parent blocks we can check
        if (iterableEndpoints.length != 0) {
            // check chronological blockNumber order
            if (parent.blockNumber + 1 != header.blockNumber) return 4;

            // check chronological timestamp order
            if (parent.timestamp >= header.timestamp) return 6;

            // check difficulty
            uint expectedDifficulty = calculateDifficulty(parent, header.timestamp);
            if (expectedDifficulty != header.difficulty) return 7;

            // validate gas limit with parent
            if (!gasLimitWithinBounds(int64(uint64(header.gasLimit)), int64(uint64(parent.gasLimit)))) return 10;
        }

        // validate gas limit
        if (header.gasUsed > header.gasLimit) return 11;

        return 0;
    }

    function gasLimitWithinBounds(int64 gasLimit, int64 parentGasLimit) private pure returns (bool) {
        int64 limit = parentGasLimit / GAS_LIMIT_BOUND_DIVISOR;
        int64 difference = gasLimit - parentGasLimit;

        if (difference < 0) {
            difference *= -1;
        }

        return difference <= limit;
    }

    // diff = (parent_diff +
    //         (parent_diff / 2048 * max((2 if len(parent.uncles) else 1) - ((timestamp - parent.timestamp) // 9), -99))
    //        ) + 2^(periodCount - 2)
    // https://github.com/ethereum/go-ethereum/blob/aa6005b469fdd1aa7a95f501ce87908011f43159/consensus/ethash/consensus.go#L335
    function calculateDifficulty(FullHeader memory parent, uint timestamp) private pure returns (uint) {
        int x = int((timestamp - parent.timestamp) / 9);

        // take into consideration uncles of parent
        if (parent.uncleHash == EMPTY_UNCLE_HASH) {
            x = 1 - x;
        } else {
            x = 2 - x;
        }

        if (x < -99) {
            x = -99;
        }

        x = int(parent.difficulty) + int(parent.difficulty) / 2048 * x;

        // minimum difficulty = 131072
        if (x < 131072) {
            x = 131072;
        }

        uint bombDelayFromParent = 5000000 - 1;
        if (parent.blockNumber + 1 >= 13773000) {
            // https://eips.ethereum.org/EIPS/eip-4345
            bombDelayFromParent = 10700000 - 1;
        } else if (parent.blockNumber + 1 >= 9200000) {
            // https://eips.ethereum.org/EIPS/eip-2384
            bombDelayFromParent = 9000000 - 1;
        }

        // calculate a fake block number for the ice-age delay
        // Specification: https://eips.ethereum.org/EIPS/eip-1234
        uint fakeBlockNumber = 0;
        if (parent.blockNumber >= bombDelayFromParent) {
            fakeBlockNumber = parent.blockNumber - bombDelayFromParent;
        }

        // for the exponential factor
        uint periodCount = fakeBlockNumber / 100000;

        // the exponential factor, commonly referred to as "the bomb"
        // diff = diff + 2^(periodCount - 2)
        if (periodCount > 1) {
            return uint(x) + 2**(periodCount - 2);
        }

        return uint(x);
    }
}
