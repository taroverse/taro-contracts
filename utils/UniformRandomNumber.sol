// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library UniformRandomNumber {
    function rand(uint256 n, uint256 seed) internal pure returns (uint256) {
        uint256 max = type(uint256).max - type(uint256).max % n;
        while (seed >= max) {
            seed = uint256(keccak256(abi.encode(seed)));
        }
        return seed % n;
    }
}