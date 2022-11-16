// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

import "./EthrelayCore.sol";
import "./RLPReader.sol";

/// @title Ethrelay: A contract enabling cross-blockchain verifications (transactions, receipts, states)
/// @author Marten Sigwart, Philipp Frauenthaler, Leonhard Esterbauer, Markus Levonyak
/// @notice You can use this contract for submitting new block headers, disputing already submitted block headers, and
///         for verifying Merkle Patricia proofs (transactions, receipts, states).
/// @dev    This contract uses the EthrelayCore contract and extends it with an incentive structure.
contract Ethrelay is EthrelayCore {

    using RLPReader for *;
    uint constant REQUIRED_STAKE_PER_BLOCK = 1 ether;
    uint constant REQUIRED_VERIFICATION_FEE_IN_WEI = 0.1 ether;
    uint8 constant VERIFICATION_TYPE_TX = 1;
    uint8 constant VERIFICATION_TYPE_RECEIPT = 2;
    uint8 constant VERIFICATION_TYPE_STATE = 3;

    mapping(address => bytes32[]) blocksSubmittedByClient;
    mapping(address => uint) clientStake;

    // The contract is initialized with block 8084509 and the total difficulty of that same block.
    // The contract creator needs to make sure that these values represent a valid block of the tracked blockchain.
    constructor(bytes memory _rlpHeader, uint totalDifficulty, address _ethashContractAddr) EthrelayCore(_rlpHeader, totalDifficulty, _ethashContractAddr) {}

    /// @dev Deposits stake for a client allowing the client to submit block headers.
    function depositStake(uint amount) payable public {
        require(amount == msg.value, "transfer amount not equal to function parameter");
        clientStake[msg.sender] = clientStake[msg.sender] + msg.value;
    }

    event WithdrawStake(address client, uint withdrawnStake);
    /// @dev Withdraws the stake of a client. The stake is reduced by the specified amount. Emits an event WithdrawStake
    ///      containing the client's address and the amount of withdrawn stake.
    function withdrawStake(uint amount) public {
        // if participant has not emitted amount stake we can for sure revert
        require(clientStake[msg.sender] >= amount, "amount higher than deposited stake");

        // else we check the unlocked stake and if enough stake is available we simply withdraw amount
        if (getUnusedStake(msg.sender) >= amount) {
            withdraw(payable(msg.sender), amount);
            emit WithdrawStake(msg.sender, amount);
            return;
        }

        // no enough free stake -> try to clean up array (search for stakes used by blocks that have already passed the lock period)
        cleanSubmitList(msg.sender);

        // if less than amount is available, we simply withdraw 0, so the client can distinguish
        // between the case a participant doesn't event hold amount stake or it is simply locked
        if (getUnusedStake(msg.sender) >= amount) {
            withdraw(payable(msg.sender), amount);
            emit WithdrawStake(msg.sender, amount);
            return;
        }

        emit WithdrawStake(msg.sender, 0);
    }

    function getStake() public view returns (uint) {
        return clientStake[msg.sender];
    }

    function getRequiredStakePerBlock() public pure returns (uint) {
        return REQUIRED_STAKE_PER_BLOCK;
    }

    function getRequiredVerificationFee() public pure returns (uint) {
        return REQUIRED_VERIFICATION_FEE_IN_WEI;
    }

    function getBlockHashesSubmittedByClient() public view returns (bytes32[] memory) {
        return blocksSubmittedByClient[msg.sender];
    }

    function submitBlock(bytes memory rlpHeader) public {
        // client must have enough stake to be able to submit blocks
        if (getUnusedStake(msg.sender) < REQUIRED_STAKE_PER_BLOCK) {
            // client has not enough unused stake -> check whether some of the blocks submitted by the client have left the lock period
            cleanSubmitList(msg.sender);
            // emit the 0x00 hash - what if this hash is really calculated? it is very very unlikely, but it is not safe
            // - should be rather safe as the mapping for headers has 0 for not present and if we don't assume this, the whole contract would be unnecessary
            // another way is to create a special error event and emmit an specific error code after cleanSubmitList that indicates the error
            // additionally, one could replace this with a require, but require reverts the state and participants have to pay fees for
            // cleanSubmitList every time#
            if (getUnusedStake(msg.sender) < REQUIRED_STAKE_PER_BLOCK) {
                // not enough unused stake -> abort
                emit NewBlock(0);
                return;
            }
        }

        // client has enough stake -> submit header and add its hash to the client's list of submitted block headers
        bytes32 blockHash = submitHeader(rlpHeader, msg.sender);

        blocksSubmittedByClient[msg.sender].push(blockHash);

        // submit hash - indicate that the block with this hash was submitted, helpful for searching the blockchain
        // for infos like rlp header needed for disputing a block
        emit NewBlock(blockHash);
    }

    // here, the same parallel problems like with single submitBlock in EthrelayCore occur: if there are two participants submitting
    // at the same time, only one is being accepted and the other one is rejected resulting in high gas costs especially
    // if the bytes memory _rlpHeaders param is quite big
    function submitBlockBatch(bytes memory _rlpHeaders) public {
        RLPReader.Iterator memory it = _rlpHeaders.toRlpItem().iterator();

        while(it.hasNext()) {
            bytes memory rlpHeader = it.next().toBytes();
            submitBlock(rlpHeader);
        }
    }

    function disputeBlockHeader(bytes calldata rlpHeader, bytes memory rlpParent, uint[] memory dataSetLookup, uint[] memory witnessForLookup) public {
        address[] memory submittersToPunish = disputeBlock(rlpHeader, rlpParent, dataSetLookup, witnessForLookup);

        // if the PoW validation initiated by the dispute function was successful (i.e., the block is legal),
        // submittersToPunish will be empty and no further action will be carried out.
        uint collectedStake = 0;

        for (uint i = 0; i < submittersToPunish.length; i++) {
            address client = submittersToPunish[i];
            clientStake[client] = clientStake[client] - REQUIRED_STAKE_PER_BLOCK;
            collectedStake += REQUIRED_STAKE_PER_BLOCK;
        }

        // client that triggered the dispute receives the collected stake
        clientStake[msg.sender] += collectedStake;
    }

    function verify(uint8 verificationType, uint feeInWei, bytes memory rlpHeader, uint8 noOfConfirmations, bytes memory rlpEncodedValue,
        bytes memory path, bytes memory rlpEncodedNodes) private returns (uint8) {

        require(feeInWei == msg.value, "transfer amount not equal to function parameter");
        require(feeInWei >= REQUIRED_VERIFICATION_FEE_IN_WEI, "provided fee is less than expected fee");

        bytes32 blockHash = keccak256(rlpHeader);
        uint8 result;

        if (verificationType == VERIFICATION_TYPE_TX) {
            result = verifyMerkleProof(blockHash, noOfConfirmations, rlpEncodedValue, path, rlpEncodedNodes, getTxRoot(rlpHeader));
        } else if (verificationType == VERIFICATION_TYPE_RECEIPT) {
            result = verifyMerkleProof(blockHash, noOfConfirmations, rlpEncodedValue, path, rlpEncodedNodes, getReceiptsRoot(rlpHeader));
        } else if (verificationType == VERIFICATION_TYPE_STATE) {
            result = verifyMerkleProof(blockHash, noOfConfirmations, rlpEncodedValue, path, rlpEncodedNodes, getStateRoot(rlpHeader));
        } else {
            revert("Unknown verification type");
        }

        // send fee to block submitter
        // (, , , , , address submitter) = getHeaderMetaInfo(blockHash);

        // address payable submitterAddr = payable(address(uint160(submitter)));

        // submitterAddr.transfer(feeInWei);

        return result;
    }

    event VerifyTransaction(uint8 result);
    /// @dev Verifies if a transaction is included in the given block's transactions Merkle Patricia trie
    /// @param feeInWei the fee that is payed for the verification and must be equal to VERIFICATION_FEE_IN_WEI.
    /// @param rlpHeader the rlp encoded header that contains the Merkle root hash
    /// @param noOfConfirmations the required number of succeeding blocks needed for a block to be considered as confirmed
    /// @param rlpEncodedTx the transaction of the Merkle Patricia trie in RLP format
    /// @param path the path (key) in the trie indicating the way starting at the root node and ending at the transaction
    /// @param rlpEncodedNodes an RLP encoded list of nodes of the Merkle branch, first element is the root node, last element the transaction
    /// @return 0: verification was successful
    ///         1: block is confirmed and unlocked, but the Merkle proof was invalid
    function verifyTransaction(uint feeInWei, bytes memory rlpHeader, uint8 noOfConfirmations, bytes memory rlpEncodedTx,
        bytes memory path, bytes memory rlpEncodedNodes) payable public returns (uint8) {

        uint8 result = verify(VERIFICATION_TYPE_TX, feeInWei, rlpHeader, noOfConfirmations, rlpEncodedTx, path, rlpEncodedNodes);

        emit VerifyTransaction(result);

        return result;
    }

    event VerifyReceipt(uint8 result);
    /// @dev Verifies if a receipt is included in the given block's receipts Merkle Patricia trie
    /// @param feeInWei the fee that is payed for the verification and must be equal to VERIFICATION_FEE_IN_WEI.
    /// @param rlpHeader the rlp encoded header that contains the Merkle root hash
    /// @param noOfConfirmations the required number of succeeding blocks needed for a block to be considered as confirmed
    /// @param rlpEncodedReceipt the receipt of the Merkle Patricia trie in RLP format
    /// @param path the path (key) in the trie indicating the way starting at the root node and ending at the receipt
    /// @param rlpEncodedNodes an RLP encoded list of nodes of the Merkle branch, first element is the root node, last element the receipt
    /// @return 0: verification was successful
    ///         1: block is confirmed and unlocked, but the Merkle proof was invalid
    function verifyReceipt(uint feeInWei, bytes memory rlpHeader, uint8 noOfConfirmations, bytes memory rlpEncodedReceipt,
        bytes memory path, bytes memory rlpEncodedNodes) payable public returns (uint8) {

        uint8 result = verify(VERIFICATION_TYPE_RECEIPT, feeInWei, rlpHeader, noOfConfirmations, rlpEncodedReceipt, path, rlpEncodedNodes);

        emit VerifyReceipt(result);

        return result;
    }

    event VerifyState(uint8 result);
    /// @dev   Verifies if a node is included in the given block's state Merkle Patricia trie
    /// @param feeInWei the fee that is payed for the verification and must be equal to VERIFICATION_FEE_IN_WEI.
    /// @param rlpHeader the rlp encoded header that contains the Merkle root hash
    /// @param noOfConfirmations the required number of succeeding blocks needed for a block to be considered as confirmed
    /// @param rlpEncodedState the node of the Merkle Patricia trie in RLP format
    /// @param path the path (key) in the trie indicating the way starting at the root node and ending at the node
    /// @param rlpEncodedNodes an RLP encoded list of nodes of the Merkle branch, first element is the root node, last element a state node
    /// @return 0: verification was successful
    ///         1: block is confirmed and unlocked, but the Merkle proof was invalid
    function verifyState(uint feeInWei, bytes memory rlpHeader, uint8 noOfConfirmations, bytes memory rlpEncodedState,
        bytes memory path, bytes memory rlpEncodedNodes) payable public returns (uint8) {

        uint8 result = verify(VERIFICATION_TYPE_STATE, feeInWei, rlpHeader, noOfConfirmations, rlpEncodedState, path, rlpEncodedNodes);

        emit VerifyState(result);

        return result;
    }

    function isBlockConfirmed(uint feeInWei, bytes32 blockHash, uint8 noOfConfirmations) public payable returns (bool) {
        require(feeInWei == msg.value, "transfer amount not equal to function parameter");
        require(feeInWei >= REQUIRED_VERIFICATION_FEE_IN_WEI, "provided fee is less than expected fee");

        return isBlockConfirmed(blockHash, noOfConfirmations);
    }

    /// @dev Calculates the fraction of the provided stake that is not used by any of the blocks in the client's list of
    ///      submitted block headers (blocksSubmittedByClient). It does not matter whether a block's lock period has already
    ///      been elapsed. As long as the block is referenced in blocksSubmittedByClient, the stake is considered as "used".
    function getUnusedStake(address client) private view returns (uint) {
        uint usedStake = blocksSubmittedByClient[client].length * REQUIRED_STAKE_PER_BLOCK;

        if (clientStake[client] < usedStake) {
            // if a client get punished due to a dispute the clientStake[client] can be less than
            // blocksSubmittedByClient[client].length * REQUIRED_STAKE_PER_BLOCK, since clientStake[client] is deducted
            // after the dispute, but blocksSubmittedByClient[client] remains unaffected (i.e., it is not cleared)
            return 0;
        } else {
            return clientStake[client] - usedStake;
        }
    }

    // take care of cleanSubmitList, maybe more gas than estimated is needed: e.g. if the time from estimating the gas costs
    // on the local machine to running the code on a node takes so long that a new block is unlocked in this time and can be
    // freed by this procedure, then gas-estimation from before is too less and an out of gas exception occur, this can easily
    // be the case if two blocks are directly relayed and submitted by the same person having less time between the submits
    // as the time from estimation to running the code lasts

    /// @dev Checks for each block referenced in blocksSubmittedByClient whether it is unlocked. In case a referenced
    ///      block's lock period has expired, its reference is removed from the list blocksSubmittedByClient.
    function cleanSubmitList(address client) private returns (uint) {
        uint deletedElements = 0;

        // this is very unpredictable as we relay on the "now" value in isUnlocked
        // and "now" relies on the timestamp a block is being mined
        // so imagine one submits blocks all the time and we don't know exactly when
        // we execute cleanSubmitList, if one is creating the contract from a genesis
        // block in the past, the contract has to catch up all the blocks until now
        // for this, one has to submit all the blocks either in batchMode so all blocks
        // are submitted at the exact same timestamp, which may run out of gas submitting
        // many blocks, so one may submit the blocks one by one or in batches, if we do this
        // we get some blocks with different lockedTimes laying directly side by side in the
        // blocksSubmittedByClient-list, in this case it can happen, that a client tries to
        // submit a block, the client estimates the gas at timestamp t where x blocks are locked,
        // the client uses f gas, after submitting the transaction, it is not guaranteed when
        // the transaction is included, it can happen, that at timestamp t + 1  where x + 1
        // blocks are unlocked, the gas consumption is much higher as we clear 1 additional block
        // and the transaction run out of gas
        // one possible workaround is to pass the time-parameter directly with the actions
        // using cleanSubmitList like withdrawStake and submitBlock, after the contract
        // checks if the date is in the past, the contract can free exactly as many blocks
        // as the client requires
        // another is to pass much more gas to the client, which as actually the simplest solution
        // additionally, we may re-implement this with a queue containing only uint16 values that
        // save the timestamps and unlock the blocks one by one to not run through the whole array
        // but that may only be a small improvement if any
        // for the default usage this is very unlikely, but can happen for sure if the client submits
        // a block, has too less stake deposited, estimates the gas and exactly at this point in time,
        // an old block is unlocked and at the estimation timestamp the client assumed there will be
        // less blocks too free if not even an exception and a rollback that does cost less than the
        // two described cases
        for (uint i = 0; i < blocksSubmittedByClient[client].length;) {
            bytes32 blockHash = blocksSubmittedByClient[client][i];

            if (!isHeaderStored(blockHash) || isUnlocked(blockHash)) {
                // block has been removed or is already unlocked (i.e., lock period has elapsed) -> remove hash from array
                uint lastElemPos = blocksSubmittedByClient[client].length - 1;
                // copy last element to position i (overwrite current elem)
                blocksSubmittedByClient[client][i] = blocksSubmittedByClient[client][lastElemPos];
                // remove last element
                blocksSubmittedByClient[client].pop();
                deletedElements += 1;
                // i is not increased, since we copied the last element to position i (otherwise the copied element would not be checked)
            } else {
                // nothing changed -> increase i and check next element
                i++;
            }
        }

        return deletedElements;
    }

    function withdraw(address payable receiver, uint amount) private {
        clientStake[receiver] = clientStake[receiver] - amount;
        receiver.transfer(amount);
    }
}
