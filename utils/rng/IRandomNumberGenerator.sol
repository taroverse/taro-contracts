// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Interface for random number generator.
 */
interface IRandomNumberGenerator {

    /**
     * Request to generating random numbers.
     * Returns a request ID.
     */
    function requestRandomNumbers(uint32 count) external returns(uint256 requestId);

    /**
     * Request to generating random numbers.
     * If the callback is not zero address, it must be an instance of VRFConsumerBaseV2Upgradeable.
     * Returns a request ID.
     */
    function requestRandomNumbers(uint32 count, address callback, uint32 callbackGasLimit) external returns(uint256 requestId);

    /**
     * Returns whether the request is complete.
     */
    function isRequestComplete(uint256 requestId) external view returns(bool isCompleted);

    /**
     * Returns the random numbers generated for the request.
     */
    function randomNumbers(uint256 requestId) external view returns(uint256[] memory randomNum);

    /**
     * Emitted when random numbers are requested.
     */
    event RandomNumbersRequested(uint256 requestId, uint32 count, address indexed sender);

    /**
     * Emitted when a request is completed.
     */
    event RequestCompleted(uint256 requestId, uint256[] randomNumbers);

    /**
     * Emitted when a request callback failed.
     */
    event RequestCallbackFailed(uint256 requestId, address callback);
}