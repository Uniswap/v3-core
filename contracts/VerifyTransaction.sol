// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

abstract contract EthrelayInterface {
    function depositStake(uint amount) payable public virtual;
    function getRequiredStakePerBlock() public pure virtual returns (uint);
    function getRequiredVerificationFee() public pure virtual returns (uint);
    function submitBlock(bytes memory rlpHeader) public virtual;
    function disputeBlockHeader(bytes calldata rlpHeader, bytes memory rlpParent, uint[] memory dataSetLookup, uint[] memory witnessForLookup) public virtual;
    function verifyTransaction(uint feeInWei, bytes memory rlpHeader, uint8 noOfConfirmations, bytes memory rlpEncodedTx,
        bytes memory path, bytes memory rlpEncodedNodes) payable public virtual returns (uint8);
    function isHeaderStored(bytes32 hash) public view virtual returns (bool);

}

contract VerifyTransaction {
    EthrelayInterface ethrelayContract;
    address payable contractAddress;

    struct TxMerkleProof {
        bytes rlpEncodedTx;
        bytes path;
        bytes rlpEncodedNodes;
    }

    struct TxMetaData {
        address from;
        address to;
        bytes input;
    }
    address private owner;
    mapping(bytes32 => TxMerkleProof) private txMerkleProofs;
    mapping(bytes32 => TxMetaData) private txsMetaData;
    mapping(uint24 => bytes) private blockRlpHeaders;
    
    event SubmittedBlock(uint blockNumber);
    event SubmittedTx(bytes32 txHash);
    modifier isOwner() {
        require(msg.sender == owner, "Not an owner");
        _;
    }

    constructor (address payable ethrelayAddr) {
        owner = msg.sender;
        contractAddress = ethrelayAddr;
        ethrelayContract = EthrelayInterface(ethrelayAddr);
    }

    event VerifyArgs(bytes blockHeader, uint8 nConfirm, bytes rlpEncodedTx, bytes path, bytes rlpEncodedNodes);
    event Verify(bytes res);
    event VerifyBool(bool b);
    function verify(uint24 blockNumber, bytes32 txHash, uint8 noOfConfirmations) payable public returns (bool) {
        uint verifyFee = ethrelayContract.getRequiredVerificationFee();
        require(msg.value >= verifyFee, "Not enough verification fee");
        require(txMerkleProofs[txHash].rlpEncodedTx.length > 0, "Trasaction is not in the repository" );
        require(blockRlpHeaders[blockNumber].length > 0, "Transaction's block is not in the repository");
        // emit Log("verify");
        for (uint24 i = 1; i <= noOfConfirmations; i++) {
            require(blockRlpHeaders[blockNumber + i].length > 0, "Do not have enough blocks to confirm");
        }

        TxMerkleProof memory txMerkleProof = txMerkleProofs[txHash];
        // emit VerifyArgs(blockRlpHeaders[blockNumber], noOfConfirmations, txMerkleProof.rlpEncodedTx, txMerkleProof.path,txMerkleProof.rlpEncodedNodes);
        (bool success , bytes memory data) = contractAddress.call{value: verifyFee}(
            abi.encodeWithSignature("verifyTransaction(uint256,bytes,uint8,bytes,bytes,bytes)",
                verifyFee, blockRlpHeaders[blockNumber], noOfConfirmations, txMerkleProof.rlpEncodedTx, txMerkleProof.path, txMerkleProof.rlpEncodedNodes)
        );
    
        emit Verify(data);
        emit VerifyBool(success);
        if (success) {
            return compareBytes(data, abi.encodePacked(uint(0)));
        } else {
            return false;
        }
    }

    function isHeaderStored(uint24 blockNumber) public view returns (bool) {
        bytes memory rlpHeader = blockRlpHeaders[blockNumber];
        return rlpHeader.length > 0 && ethrelayContract.isHeaderStored(keccak256(rlpHeader));
    }

    function submitBlock(uint24 blockNumber, bytes memory rlpHeader) public isOwner {
        ethrelayContract.submitBlock(rlpHeader);
        // require(ethrelayContract.isHeaderStored(keccak256(rlpHeader)), "Failed to store block header");
        blockRlpHeaders[blockNumber] = rlpHeader;

        emit SubmittedBlock(blockNumber);
    }

    function submitAndVerifyBlock(uint24 blockNumber, bytes memory rlpHeader, bytes memory rlpParent, uint[] memory dataSetLookup, uint[] memory witnessForLookup) public isOwner {
        ethrelayContract.submitBlock(rlpHeader);
        ethrelayContract.disputeBlockHeader(rlpHeader, rlpParent, dataSetLookup, witnessForLookup);
        require(ethrelayContract.isHeaderStored(keccak256(rlpHeader)), "Failed to store block header");
        blockRlpHeaders[blockNumber] = rlpHeader;

        emit SubmittedBlock(blockNumber);
    }

    function submitTx(bytes32 txHash, bytes memory rlpEncodedTx, bytes memory path, bytes memory rlpEncodedNodes) public isOwner {
        txMerkleProofs[txHash] = TxMerkleProof(rlpEncodedTx, path, rlpEncodedNodes);
        emit SubmittedTx(txHash);
    }
    
    function submitTxMetaData(bytes32 txHash, address from, address to, bytes memory input) public isOwner {
        txsMetaData[txHash] = TxMetaData(from, to, input);
    }

    event Deposit(bool res);
    function deposit() public payable returns (bool) {
        (bool success, ) = contractAddress.call{value: msg.value}(
            abi.encodeWithSignature("depositStake(uint256)", msg.value)
        );
        emit Deposit(success);
        return success;
    }

    function getRequiredVerificationFee() public view returns (uint) {
        return ethrelayContract.getRequiredVerificationFee();
    }

    function getRequiredStakePerBlock() public view returns (uint) {
        return ethrelayContract.getRequiredStakePerBlock();
    }

    function getTxMetaData(bytes32 txHash) public view returns (address, address, bytes memory) {
        TxMetaData memory txMetaData = txsMetaData[txHash];
        require(txMetaData.from != address(0), "Transaction not found");
        
        return (txMetaData.from, txMetaData.to, txMetaData.input);
    }

    function compareBytes(bytes memory b1, bytes memory b2) internal pure returns (bool) {
        if (b1.length != b2.length) {
            return false;
        }

        for (uint i = 0; i < b1.length; i++) {
            if (b1[i] != b2[i]) {
                return false;
            }
        }

        return true;
    }
}