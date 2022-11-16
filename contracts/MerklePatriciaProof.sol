// SPDX-License-Identifier: Apache-2.0
/*
 * @title MerklePatriciaVerifier
 * @author Sam Mayo (sammayo888@gmail.com)
 *         Changes: Philipp Frauenthaler, Marten Sigwart, Markus Levonyak
 *
 * @dev Library for verifing merkle patricia proofs.
 */
pragma solidity >=0.5.10 <0.9.0;
import "./RLPReader.sol";

library MerklePatriciaProof {
    /*
     * @dev Verifies a merkle patricia proof.
     * @param value The terminating value in the trie.
     * @param path The path in the trie leading to value.
     * @param rlpParentNodes The rlp encoded stack of nodes.
     * @param root The root hash of the trie.
     * @return return code indicating result. Return code 0 indicates a positive verification
     */
    function verify(bytes memory value, bytes memory encodedPath, bytes memory rlpParentNodes, bytes32 root) internal pure returns (uint code) {
        RLPReader.RLPItem memory item = RLPReader.toRlpItem(rlpParentNodes);

        // list of the rlp encoded proof nodes
        // [node1, node2, node3...]
        RLPReader.RLPItem[] memory parentNodes = RLPReader.toList(item);

        bytes memory currentNode;
        RLPReader.RLPItem[] memory currentNodeList;

        // merkle-root hash - this should be calculated by all the following child-nodes
        bytes32 nodeKey = root;

        // current height-level of the trie
        uint pathPtr = 0;

        // [8, 1, 8, 8]
        bytes memory path = _getNibbleArray(encodedPath);

        // path is empty - this is equal as
        if (path.length == 0) { return (1); }

        // iterate all the rlp encoded nodes in the proof
        for (uint i = 0; i < parentNodes.length; i++) {

            // the actual path is longer than the given path - key not found
            if (pathPtr > path.length) { return (2); }

            // next node in the proof is read
            currentNode = RLPReader.toBytes(parentNodes[i]);

            // the hash of the current-node does not represent the desired nodeKey, this is especially the case at the
            // beginning of the proof where the transactionRootHash is verified
            if (nodeKey != keccak256(currentNode)) { return (3); }

            // the proof-node is transformed into the byte-array containing key/value/branch nodes depending on the type of the proof node
            currentNodeList = RLPReader.toList(RLPReader.toRlpItem(currentNode));

            if (currentNodeList.length == 17) {
                // branch node

                // we reached at the given level
                if (pathPtr == path.length) {
                    if (keccak256(RLPReader.toBytes(currentNodeList[16])) == keccak256(value)) {
                        return (0);
                    } else {
                        return (4);
                    }
                }

                uint8 nextPathNibble = uint8(path[pathPtr]);

                if (nextPathNibble > 16) {
                    return (5);
                }

                nodeKey = bytes32(RLPReader.toUint(currentNodeList[nextPathNibble]));

                pathPtr += 1;
            } else if (currentNodeList.length == 2) {
                // extension or leaf node

                pathPtr += _nibblesToTraverse(RLPReader.toBytes(currentNodeList[0]), path, pathPtr);

                if (pathPtr == path.length) {//leaf node
                    if (keccak256(RLPReader.toBytes(currentNodeList[1])) == keccak256(value)) {
                        return (0);
                    } else {
                        return (6);
                    }
                }
                //extension node
                if (_nibblesToTraverse(RLPReader.toBytes(currentNodeList[0]), path, pathPtr) == 0) {
                    return (7);
                }

                nodeKey = bytes32(RLPReader.toUint(currentNodeList[1]));
            } else {
                return (8);
            }
        }
    }

    function _nibblesToTraverse(bytes memory encodedPartialPath, bytes memory path, uint pathPtr) private pure returns (uint) {
        uint len;
        // encodedPartialPath has elements that are each two hex characters (1 byte), but partialPath
        // and slicedPath have elements that are each one hex character (1 nibble)
        bytes memory partialPath = _getNibbleArrayEncoding(encodedPartialPath);
        bytes memory slicedPath = new bytes(partialPath.length);

        // pathPtr counts nibbles in path
        // partialPath.length is a number of nibbles
        for (uint i=pathPtr; i<pathPtr+partialPath.length; i++) {
            bytes1 pathNibble = path[i];
            slicedPath[i-pathPtr] = pathNibble;
        }

        if (keccak256(partialPath) == keccak256(slicedPath)) {
            len = partialPath.length;
        } else {
            len = 0;
        }
        return len;
    }

    // bytes b must be hp encoded
    function _getNibbleArrayEncoding(bytes memory b) private pure returns (bytes memory) {
        bytes memory nibbles;
        if (b.length>0) {
            uint8 offset;
            uint8 hpNibble = uint8(_getNthNibbleOfBytes(0,b));
            if (hpNibble == 1 || hpNibble == 3) {
                nibbles = new bytes(b.length*2-1);
                bytes1 oddNibble = _getNthNibbleOfBytes(1,b);
                nibbles[0] = oddNibble;
                offset = 1;
            } else {
                nibbles = new bytes(b.length*2-2);
                offset = 0;
            }

            for (uint i = offset; i < nibbles.length; i++) {
                nibbles[i] = _getNthNibbleOfBytes(i-offset+2,b);
            }
        }
        return nibbles;
    }

    // this function creates a bytes array where each element contains the value of 4 bits of a byte
    // the 1 byte (8-bit) - array is split into a 4-bit array so to say
    // example: byte-array in hex representation: [81, 88] will be transformed to [8, 1, 8, 8]
    // normal byte array, no special encoding/decoding used
    function _getNibbleArray(bytes memory b) private pure returns (bytes memory) {
        bytes memory nibbles = new bytes(b.length*2);
        for (uint i = 0; i < nibbles.length; i++) {
            nibbles[i] = _getNthNibbleOfBytes(i, b);
        }
        return nibbles;
    }

    /*
     * this function takes in the bytes string (hp encoded (hex-prefix encoded)) and the value of N, to return the Nth nibble.
     *@param Value of N
     *@param Bytes String
     *@return ByteString[N]
     */
    function _getNthNibbleOfBytes(uint n, bytes memory str) private pure returns (bytes1) {
        return bytes1(n%2==0 ? uint8(str[n/2])/0x10 : uint8(str[n/2])%0x10);
    }

}
