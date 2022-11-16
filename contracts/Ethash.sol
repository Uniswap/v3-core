pragma solidity >=0.7.0 <0.9.0;

/// @dev These contracts are used to verify Proof of Work within a smart contract.
///      The algorithms have been extracted from the implementation of smart pool (https://github.com/smartpool)
contract SHA3_512 {
    constructor() {}

    function keccak_f(uint[25] memory A) pure private returns(uint[25] memory) {
        uint[25] memory B;
        uint[5]  memory C;
        uint[5]  memory D;

        uint[24] memory RC= [
        uint(0x0000000000000001),
        0x0000000000008082,
        0x800000000000808A,
        0x8000000080008000,
        0x000000000000808B,
        0x0000000080000001,
        0x8000000080008081,
        0x8000000000008009,
        0x000000000000008A,
        0x0000000000000088,
        0x0000000080008009,
        0x000000008000000A,
        0x000000008000808B,
        0x800000000000008B,
        0x8000000000008089,
        0x8000000000008003,
        0x8000000000008002,
        0x8000000000000080,
        0x000000000000800A,
        0x800000008000000A,
        0x8000000080008081,
        0x8000000000008080,
        0x0000000080000001,
        0x8000000080008008 ];

        for( uint i = 0 ; i < 24 ; i++ ) {

            C[0]=A[0]^A[1]^A[2]^A[3]^A[4];
            C[1]=A[5]^A[6]^A[7]^A[8]^A[9];
            C[2]=A[10]^A[11]^A[12]^A[13]^A[14];
            C[3]=A[15]^A[16]^A[17]^A[18]^A[19];
            C[4]=A[20]^A[21]^A[22]^A[23]^A[24];

            D[0]=C[4] ^ ((C[1] * 2)&0xffffffffffffffff | (C[1] / (2 ** 63)));
            D[1]=C[0] ^ ((C[2] * 2)&0xffffffffffffffff | (C[2] / (2 ** 63)));
            D[2]=C[1] ^ ((C[3] * 2)&0xffffffffffffffff | (C[3] / (2 ** 63)));
            D[3]=C[2] ^ ((C[4] * 2)&0xffffffffffffffff | (C[4] / (2 ** 63)));
            D[4]=C[3] ^ ((C[0] * 2)&0xffffffffffffffff | (C[0] / (2 ** 63)));

            A[0]=A[0] ^ D[0];
            A[1]=A[1] ^ D[0];
            A[2]=A[2] ^ D[0];
            A[3]=A[3] ^ D[0];
            A[4]=A[4] ^ D[0];
            A[5]=A[5] ^ D[1];
            A[6]=A[6] ^ D[1];
            A[7]=A[7] ^ D[1];
            A[8]=A[8] ^ D[1];
            A[9]=A[9] ^ D[1];
            A[10]=A[10] ^ D[2];
            A[11]=A[11] ^ D[2];
            A[12]=A[12] ^ D[2];
            A[13]=A[13] ^ D[2];
            A[14]=A[14] ^ D[2];
            A[15]=A[15] ^ D[3];
            A[16]=A[16] ^ D[3];
            A[17]=A[17] ^ D[3];
            A[18]=A[18] ^ D[3];
            A[19]=A[19] ^ D[3];
            A[20]=A[20] ^ D[4];
            A[21]=A[21] ^ D[4];
            A[22]=A[22] ^ D[4];
            A[23]=A[23] ^ D[4];
            A[24]=A[24] ^ D[4];

            /*Rho and pi steps*/
            B[0]=A[0];
            B[8]=((A[1] * (2 ** 36))&0xffffffffffffffff | (A[1] / (2 ** 28)));
            B[11]=((A[2] * (2 ** 3))&0xffffffffffffffff | (A[2] / (2 ** 61)));
            B[19]=((A[3] * (2 ** 41))&0xffffffffffffffff | (A[3] / (2 ** 23)));
            B[22]=((A[4] * (2 ** 18))&0xffffffffffffffff | (A[4] / (2 ** 46)));
            B[2]=((A[5] * (2 ** 1))&0xffffffffffffffff | (A[5] / (2 ** 63)));
            B[5]=((A[6] * (2 ** 44))&0xffffffffffffffff | (A[6] / (2 ** 20)));
            B[13]=((A[7] * (2 ** 10))&0xffffffffffffffff | (A[7] / (2 ** 54)));
            B[16]=((A[8] * (2 ** 45))&0xffffffffffffffff | (A[8] / (2 ** 19)));
            B[24]=((A[9] * (2 ** 2))&0xffffffffffffffff | (A[9] / (2 ** 62)));
            B[4]=((A[10] * (2 ** 62))&0xffffffffffffffff | (A[10] / (2 ** 2)));
            B[7]=((A[11] * (2 ** 6))&0xffffffffffffffff | (A[11] / (2 ** 58)));
            B[10]=((A[12] * (2 ** 43))&0xffffffffffffffff | (A[12] / (2 ** 21)));
            B[18]=((A[13] * (2 ** 15))&0xffffffffffffffff | (A[13] / (2 ** 49)));
            B[21]=((A[14] * (2 ** 61))&0xffffffffffffffff | (A[14] / (2 ** 3)));
            B[1]=((A[15] * (2 ** 28))&0xffffffffffffffff | (A[15] / (2 ** 36)));
            B[9]=((A[16] * (2 ** 55))&0xffffffffffffffff | (A[16] / (2 ** 9)));
            B[12]=((A[17] * (2 ** 25))&0xffffffffffffffff | (A[17] / (2 ** 39)));
            B[15]=((A[18] * (2 ** 21))&0xffffffffffffffff | (A[18] / (2 ** 43)));
            B[23]=((A[19] * (2 ** 56))&0xffffffffffffffff | (A[19] / (2 ** 8)));
            B[3]=((A[20] * (2 ** 27))&0xffffffffffffffff | (A[20] / (2 ** 37)));
            B[6]=((A[21] * (2 ** 20))&0xffffffffffffffff | (A[21] / (2 ** 44)));
            B[14]=((A[22] * (2 ** 39))&0xffffffffffffffff | (A[22] / (2 ** 25)));
            B[17]=((A[23] * (2 ** 8))&0xffffffffffffffff | (A[23] / (2 ** 56)));
            B[20]=((A[24] * (2 ** 14))&0xffffffffffffffff | (A[24] / (2 ** 50)));

            /*Xi state*/
            A[0]=B[0]^((~B[5]) & B[10]);
            A[1]=B[1]^((~B[6]) & B[11]);
            A[2]=B[2]^((~B[7]) & B[12]);
            A[3]=B[3]^((~B[8]) & B[13]);
            A[4]=B[4]^((~B[9]) & B[14]);
            A[5]=B[5]^((~B[10]) & B[15]);
            A[6]=B[6]^((~B[11]) & B[16]);
            A[7]=B[7]^((~B[12]) & B[17]);
            A[8]=B[8]^((~B[13]) & B[18]);
            A[9]=B[9]^((~B[14]) & B[19]);
            A[10]=B[10]^((~B[15]) & B[20]);
            A[11]=B[11]^((~B[16]) & B[21]);
            A[12]=B[12]^((~B[17]) & B[22]);
            A[13]=B[13]^((~B[18]) & B[23]);
            A[14]=B[14]^((~B[19]) & B[24]);
            A[15]=B[15]^((~B[20]) & B[0]);
            A[16]=B[16]^((~B[21]) & B[1]);
            A[17]=B[17]^((~B[22]) & B[2]);
            A[18]=B[18]^((~B[23]) & B[3]);
            A[19]=B[19]^((~B[24]) & B[4]);
            A[20]=B[20]^((~B[0]) & B[5]);
            A[21]=B[21]^((~B[1]) & B[6]);
            A[22]=B[22]^((~B[2]) & B[7]);
            A[23]=B[23]^((~B[3]) & B[8]);
            A[24]=B[24]^((~B[4]) & B[9]);

            /*Last step*/
            A[0]=A[0]^RC[i];
        }

        return A;
    }


    function sponge(uint[9] memory M) pure internal returns(uint[16] memory) {
        require((M.length * 8) == 72, "sponge error");

        M[5] = 0x01;
        M[8] = 0x8000000000000000;

        uint r = 72;
        uint w = 8;
        uint size = M.length * 8;

        uint[25] memory S;
        uint i; uint y; uint x;
        /*Absorbing Phase*/
        for( i = 0 ; i < size/r ; i++ ) {
            for( y = 0 ; y < 5 ; y++ ) {
                for( x = 0 ; x < 5 ; x++ ) {
                    if( (x+5*y) < (r/w) ) {
                        S[5*x+y] = S[5*x+y] ^ M[i*9 + x + 5*y];
                    }
                }
            }
            S = keccak_f(S);
        }

        /*Squeezing phase*/
        uint[16] memory result;
        uint b = 0;
        while( b < 16 ) {
            for( y = 0 ; y < 5 ; y++ ) {
                for( x = 0 ; x < 5 ; x++ ) {
                    if( (x+5*y)<(r/w) && (b<16) ) {
                        result[b] = S[5*x+y] & 0xFFFFFFFF;
                        result[b+1] = S[5*x+y] / 0x100000000;
                        b+=2;
                    }
                }
            }
        }

        return result;
    }

}

////////////////////////////////////////////////////////////////////////////////

contract Ethash is SHA3_512 {

    uint constant EPOCH_LENGTH = 30000;   // blocks per epoch

    constructor() {
    }

    function fnv( uint v1, uint v2 ) pure internal returns(uint) {
        return ((v1*0x01000193) ^ v2) & 0xFFFFFFFF;
    }

    function computeCacheRoot( uint index,
        uint indexInElementsArray,
        uint[] memory elements,
        uint[] memory witness,
        uint branchSize ) pure private returns(uint) {

        uint leaf = computeLeaf(elements, indexInElementsArray) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        uint left;
        uint right;
        uint node;
        bool oddBranchSize = (branchSize % 2) > 0;

        assembly {
            branchSize := div(branchSize,2)
        //branchSize /= 2;
        }
        uint witnessIndex = indexInElementsArray * branchSize;
        if( oddBranchSize ) witnessIndex += indexInElementsArray;

        uint depth;
        for( depth = 0 ; depth < branchSize ; depth++ ) {
            assembly {
                node := mload(add(add(witness,0x20),mul(add(depth,witnessIndex),0x20)))
            }
            //node  = witness[witnessIndex + depth] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            if( index & 0x1 == 0 ) {
                left = leaf;
                assembly{
                    right := and(node,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                }

            }
            else {
                assembly{
                    left := and(node,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                }
                right = leaf;
            }

            leaf = uint(keccak256(abi.encodePacked(left,right))) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            assembly {
                index := div(index,2)
            }

            //node  = witness[witnessIndex + depth] / (2**128);
            if( index & 0x1 == 0 ) {
                left = leaf;
                assembly{
                    right := div(node,0x100000000000000000000000000000000)
                }
            }
            else {
                assembly {
                    left := div(node,0x100000000000000000000000000000000)
                }
                right = leaf;
            }

            leaf = uint(keccak256(abi.encodePacked(left,right))) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            assembly {
                index := div(index,2)
            }
        }

        if( oddBranchSize ) {
            assembly {
                node := mload(add(add(witness,0x20),mul(add(depth,witnessIndex),0x20)))
            }

            //node  = witness[witnessIndex + depth] & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            if( index & 0x1 == 0 ) {
                left = leaf;
                assembly{
                    right := and(node,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                }
            }
            else {
                assembly{
                    left := and(node,0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
                }

                right = leaf;
            }

            leaf = uint(keccak256(abi.encodePacked(left,right))) & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        }


        return leaf;
    }

    function toBE( uint x ) pure internal returns(uint) {
        uint y = 0;
        for( uint i = 0 ; i < 32 ; i++ ) {
            y = y * 256;
            y += (x & 0xFF);
            x = x / 256;
        }

        return y;

    }

    function computeSha3( uint[16] memory s, uint[8] memory cmix ) pure internal returns(uint) {
        uint s0 = s[0] + s[1] * (2**32) + s[2] * (2**64) + s[3] * (2**96) +
        (s[4] + s[5] * (2**32) + s[6] * (2**64) + s[7] * (2**96))*(2**128);

        uint s1 = s[8] + s[9] * (2**32) + s[10] * (2**64) + s[11] * (2**96) +
        (s[12] + s[13] * (2**32) + s[14] * (2**64) + s[15] * (2**96))*(2**128);

        uint c = cmix[0] + cmix[1] * (2**32) + cmix[2] * (2**64) + cmix[3] * (2**96) +
        (cmix[4] + cmix[5] * (2**32) + cmix[6] * (2**64) + cmix[7] * (2**96))*(2**128);


        /* god knows why need to convert to big endian */
        return uint( keccak256(abi.encodePacked(toBE(s0),toBE(s1),toBE(c))) );
    }


    function computeLeaf( uint[] memory dataSetLookup, uint index ) pure internal returns(uint) {
        return uint( keccak256(abi.encodePacked(
                dataSetLookup[4*index],
                dataSetLookup[4*index + 1],
                dataSetLookup[4*index + 2],
                dataSetLookup[4*index + 3]
            )) );

    }

    function computeS( uint header, uint nonceLe ) pure internal returns(uint[16] memory) {
        uint[9] memory M;

        header = reverseBytes(header);

        M[0] = uint(header) & 0xFFFFFFFFFFFFFFFF;
        header = header / 2**64;
        M[1] = uint(header) & 0xFFFFFFFFFFFFFFFF;
        header = header / 2**64;
        M[2] = uint(header) & 0xFFFFFFFFFFFFFFFF;
        header = header / 2**64;
        M[3] = uint(header) & 0xFFFFFFFFFFFFFFFF;

        // make little endian nonce
        M[4] = nonceLe;
        return sponge(M);
    }

    function reverseBytes( uint input ) pure internal returns(uint) {
        uint result = 0;
        for(uint i = 0 ; i < 32 ; i++ ) {
            result = result * 256;
            result += input & 0xff;

            input /= 256;
        }

        return result;
    }

    struct EthashCacheOptData {
        uint[512]    merkleNodes;
        uint         fullSizeIn128Resultion;
        uint         branchDepth;
    }

    mapping(uint=>EthashCacheOptData) epochData;

    function isEpochDataSet( uint epochIndex ) public view returns(bool) {
        return epochData[epochIndex].fullSizeIn128Resultion != 0;

    }

    event SetEpochData( address indexed sender, uint error, uint errorInfo );
    function setEpochData( uint epoch,
        uint fullSizeIn128Resultion,
        uint branchDepth,
        uint[] memory merkleNodes,
        uint start,
        uint numElems ) public {

        for( uint i = 0 ; i < numElems ; i++ ) {
            if( epochData[epoch].merkleNodes[start+i] > 0 ) {
                //ErrorLog("epoch already set", epoch[i]);
                emit SetEpochData( msg.sender, 1, epoch * (2**128) + start + i );
                return;
            }
            epochData[epoch].merkleNodes[start+i] = merkleNodes[i];
        }
        epochData[epoch].fullSizeIn128Resultion = fullSizeIn128Resultion;
        epochData[epoch].branchDepth = branchDepth;

        emit SetEpochData( msg.sender, 0 , 0 );
    }

    function getMerkleLeave( uint epochIndex, uint p ) view internal returns(uint) {
        uint rootIndex = uint(p >> epochData[epochIndex].branchDepth);
        uint expectedRoot = epochData[epochIndex].merkleNodes[(rootIndex/2)];
        if( (rootIndex % 2) == 0 ) expectedRoot = expectedRoot & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
        else expectedRoot = expectedRoot / (2**128);

        return expectedRoot;
    }

    function hashimoto( bytes32 header,
        uint          nonceLe,
        uint[] memory dataSetLookup,
        uint[] memory witnessForLookup,
        uint          epochIndex ) private view returns(uint) {

        uint[16] memory s;
        uint[32] memory mix;
        uint[8]  memory cmix;

        uint[2]  memory depthAndFullSize = [epochData[epochIndex].branchDepth,
        epochData[epochIndex].fullSizeIn128Resultion];

        uint i;
        uint j;

        if( ! isEpochDataSet( epochIndex ) ) return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE;

        s = computeS(uint(header), nonceLe);
        for( i = 0 ; i < 16 ; i++ ) {
            assembly {
                let offset := mul(i,0x20)

                //mix[i] = s[i];
                mstore(add(mix,offset),mload(add(s,offset)))

                // mix[i+16] = s[i];
                mstore(add(mix,add(0x200,offset)),mload(add(s,offset)))
            }
        }

        for( i = 0 ; i < 64 ; i++ ) {
            uint p = fnv( i ^ s[0], mix[i % 32]) % depthAndFullSize[1];


            if( computeCacheRoot( p, i, dataSetLookup,  witnessForLookup, depthAndFullSize[0] )  != getMerkleLeave( epochIndex, p ) ) {

                // PoW failed
                return 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
            }

            for( j = 0 ; j < 8 ; j++ ) {

                assembly{
                    //mix[j] = fnv(mix[j], dataSetLookup[4*i] & varFFFFFFFF );
                    let dataOffset := add(mul(0x80,i),add(dataSetLookup,0x20))
                    let dataValue   := and(mload(dataOffset),0xFFFFFFFF)

                    let mixOffset := add(mix,mul(0x20,j))
                    let mixValue  := mload(mixOffset)

                    // fnv = return ((v1*0x01000193) ^ v2) & 0xFFFFFFFF;
                    let fnvValue := and(xor(mul(mixValue,0x01000193),dataValue),0xFFFFFFFF)
                    mstore(mixOffset,fnvValue)

                    //mix[j+8] = fnv(mix[j+8], dataSetLookup[4*i + 1] & 0xFFFFFFFF );
                    dataOffset := add(dataOffset,0x20)
                    dataValue   := and(mload(dataOffset),0xFFFFFFFF)

                    mixOffset := add(mixOffset,0x100)
                    mixValue  := mload(mixOffset)

                    // fnv = return ((v1*0x01000193) ^ v2) & 0xFFFFFFFF;
                    fnvValue := and(xor(mul(mixValue,0x01000193),dataValue),0xFFFFFFFF)
                    mstore(mixOffset,fnvValue)

                    //mix[j+16] = fnv(mix[j+16], dataSetLookup[4*i + 2] & 0xFFFFFFFF );
                    dataOffset := add(dataOffset,0x20)
                    dataValue   := and(mload(dataOffset),0xFFFFFFFF)

                    mixOffset := add(mixOffset,0x100)
                    mixValue  := mload(mixOffset)

                    // fnv = return ((v1*0x01000193) ^ v2) & 0xFFFFFFFF;
                    fnvValue := and(xor(mul(mixValue,0x01000193),dataValue),0xFFFFFFFF)
                    mstore(mixOffset,fnvValue)

                    //mix[j+24] = fnv(mix[j+24], dataSetLookup[4*i + 3] & 0xFFFFFFFF );
                    dataOffset := add(dataOffset,0x20)
                    dataValue   := and(mload(dataOffset),0xFFFFFFFF)

                    mixOffset := add(mixOffset,0x100)
                    mixValue  := mload(mixOffset)

                    // fnv = return ((v1*0x01000193) ^ v2) & 0xFFFFFFFF;
                    fnvValue := and(xor(mul(mixValue,0x01000193),dataValue),0xFFFFFFFF)
                    mstore(mixOffset,fnvValue)

                }


                //mix[j] = fnv(mix[j], dataSetLookup[4*i] & 0xFFFFFFFF );
                //mix[j+8] = fnv(mix[j+8], dataSetLookup[4*i + 1] & 0xFFFFFFFF );
                //mix[j+16] = fnv(mix[j+16], dataSetLookup[4*i + 2] & 0xFFFFFFFF );
                //mix[j+24] = fnv(mix[j+24], dataSetLookup[4*i + 3] & 0xFFFFFFFF );


                //dataSetLookup[4*i    ] = dataSetLookup[4*i    ]/(2**32);
                //dataSetLookup[4*i + 1] = dataSetLookup[4*i + 1]/(2**32);
                //dataSetLookup[4*i + 2] = dataSetLookup[4*i + 2]/(2**32);
                //dataSetLookup[4*i + 3] = dataSetLookup[4*i + 3]/(2**32);

                assembly{
                    let offset := add(add(dataSetLookup,0x20),mul(i,0x80))
                    let value  := div(mload(offset),0x100000000)
                    mstore(offset,value)

                    offset := add(offset,0x20)
                    value  := div(mload(offset),0x100000000)
                    mstore(offset,value)

                    offset := add(offset,0x20)
                    value  := div(mload(offset),0x100000000)
                    mstore(offset,value)

                    offset := add(offset,0x20)
                    value  := div(mload(offset),0x100000000)
                    mstore(offset,value)
                }
            }
        }


        for( i = 0 ; i < 32 ; i += 4) {
            cmix[i/4] = (fnv(fnv(fnv(mix[i], mix[i+1]), mix[i+2]), mix[i+3]));
        }

        uint result = computeSha3(s,cmix);

        return result;

    }

    function verifyPoW(uint blockNumber, bytes32 rlpHeaderHashWithoutNonce, uint nonce, uint difficulty,
        uint[] calldata dataSetLookup, uint[] calldata witnessForLookup) external view returns (uint, uint) {

        // verify ethash
        uint epoch = blockNumber / EPOCH_LENGTH;
        uint ethash = hashimoto(rlpHeaderHashWithoutNonce, nonce, dataSetLookup, witnessForLookup, epoch);

        if( ethash > (2**256-1)/difficulty) {
            uint errorCode;
            uint errorInfo;
            if( ethash == 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE ) {
                // Required epoch data not set
                errorCode = 1;
                errorInfo = epoch;
            }
            else {
                // ethash difficulty too low
                errorCode = 2;
                errorInfo = ethash;
            }
            return (errorCode, errorInfo);
        }

        return (0, 0);
    }
}
