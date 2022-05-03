// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library ArrayUtils {

    function map(
        uint256[] memory A, function (uint256) pure returns(uint256) fn
    ) internal pure returns(uint256[] memory) {
        uint256 length = A.length;
        uint256[] memory mapped = new uint256[](length);
        for (uint256 i = 0; i < length;) {
            mapped[i] = fn(A[i]);
            unchecked { i++; }
        }
        return mapped;
    }

    function reduce(
        uint256[] memory A, function (uint256, uint256) pure returns(uint256) fn
    ) internal pure returns(uint256) {
        uint256 reduced = A[0];
        uint256 length = A.length;
        for (uint256 i = 1; i < length;) {
            reduced = fn(reduced, A[i]);
            unchecked { i++; }
        }
        return reduced;
    }

    function difference(
        uint256[] memory A, uint256[] memory B
    ) internal pure returns(uint256[] memory) {
        unchecked {
            uint256 length = A.length;
            bool[] memory includeMap = new bool[](length);
            uint256 count = 0;
            for (uint256 i = 0; i < length; i++) {
                if (!contains(B, A[i])) {
                    includeMap[i] = true;
                    count++;
                }
            }
            uint256[] memory filtered = new uint256[](count);
            uint256 j = 0;
            for (uint256 i = 0; i < length; i++) {
                if (includeMap[i]) {
                    filtered[j] = A[i];
                    j++;
                }
            }
            return filtered;
        }
    }

    function filter(
        uint256[] memory A, function (uint256) pure returns(bool) predicate
    ) internal pure returns(uint256[] memory) {
        uint256 length = A.length;
        bool[] memory includeMap = new bool[](length);
        uint256 count = 0;
        for (uint256 i = 0; i < length;) {
            if (predicate(A[i])) {
                includeMap[i] = true;
                unchecked { count++; }
            }

            unchecked { i++; }
        }
        uint256[] memory filtered = new uint256[](count);
        uint256 j = 0;
        for (uint256 i = 0; i < length;) {
            if (includeMap[i]) {
                filtered[j] = A[i];
                unchecked { j++; }
            }

            unchecked { i++; }
        }
        return filtered;
    }

    // function argFilter(
    //     uint256[] memory A, function (uint256) pure returns(bool) predicate
    // ) internal pure returns(uint256[] memory) {
    //     uint256 length = A.length;
    //     bool[] memory includeMap = new bool[](length);
    //     uint256 count = 0;
    //     for (uint256 i = 0; i < length;) {
    //         if (predicate(A[i])) {
    //             includeMap[i] = true;
    //             unchecked { count++; }
    //         }
    //         unchecked { i++; }
    //     }
    //     uint256[] memory indexArray = new uint256[](count);
    //     uint256 j = 0;
    //     for (uint256 i = 0; i < length;) {
    //         if (includeMap[i]) {
    //             indexArray[j] = i;
    //             unchecked { j++; }
    //         }
    //         unchecked { i++; }
    //     }
    //     return indexArray;
    // }

    // function argGet(
    //     uint256[] memory A, uint256[] memory indexArray
    // ) internal pure returns(uint256[] memory) {
    //     uint256 length = indexArray.length;
    //     uint256[] memory array = new uint256[](length);
    //     for (uint256 i = 0; i < length;) {
    //         array[i] = A[indexArray[i]];
    //         unchecked { i++; }
    //     }
    //     return array;
    // }

    /**
     * @return Returns index and isIn for the first occurrence starting from index 0
     */
    function indexOf(uint256[] memory A, uint256 val) internal pure returns(uint256, bool) {
        unchecked {
            uint256 length = A.length;
            for (uint256 i = 0; i < length; i++) {
                if (A[i] == val) {
                    return (i, true);
                }
            }
            return (0, false);
        }
    }

    function contains(uint256[] memory A, uint256 val) internal pure returns(bool) {
        unchecked {
            uint256 length = A.length;
            for (uint256 i = 0; i < length; i++) {
                if (A[i] == val) {
                    return true;
                }
            }
            return false;
        }
    }

    function isEqual(uint256[] memory A, uint256[] memory B) internal pure returns(bool) {
        unchecked {
            uint256 length = A.length;
            if (length != B.length) {
                return false;
            }
            for (uint256 i = 0; i < length; i++) {
                if (A[i] != B[i]) {
                    return false;
                }
            }
            return true;
        }
    }

    // function equal(uint256[] memory A, uint256[] memory B) internal pure returns(bool) {
    //     return isEqual(A, B);
    // }

    // function eq(uint256[] memory A, uint256[] memory B) internal pure returns(bool) {
    //     return isEqual(A, B);
    // }

}