// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "./VRFConsumerBaseV2Upgradeable.sol";
import "./RandomNumberGeneratorLogic.sol";

/**
 * Generates random numbers using Chainlink VRF.
 */
contract ChainlinkRandomNumberGenerator is RandomNumberGeneratorLogic, VRFConsumerBaseV2Upgradeable {
    VRFCoordinatorV2Interface private COORDINATOR;
    LinkTokenInterface private LINKTOKEN;

    // subscription ID
    uint64 private s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 private s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 constant s_callbackBaseGasLimit = 80000;
    uint32 constant s_callbackAdditionalGasLimit = 20000;

    // The default is 3, but you can set this higher.
    uint16 constant s_requestConfirmations = 3;

    event ConfigSet(uint64 subscriptionId, bytes32 keyHash);

    /**
     * VRF coordinator, LINK token and key hash are network dependent.
     * Check them here: https://docs.chain.link/docs/vrf-contracts/#configurations
     */
    function initialize(
        uint64 subscriptionId,
        address vrfCoordinator,
        address link,
        bytes32 keyHash
    ) public virtual initializer {
        __RandomNumberGeneratorLogic_init();
        __VRFConsumerBaseV2_init(vrfCoordinator);

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
    }

    function setConfig(uint64 subscriptionId, bytes32 keyHash) external onlyRole(DEFAULT_ADMIN_ROLE) {
        s_keyHash = keyHash;
        s_subscriptionId = subscriptionId;
        emit ConfigSet(subscriptionId, keyHash);
    }

    /**
     * Ask Chainlink to generate random numbers.
     */
    function _requestRandomNumbers(uint32 count, uint32 callbackGasLimit) internal virtual override returns (uint256 requestId) {
        return COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            s_requestConfirmations,
            s_callbackBaseGasLimit + s_callbackAdditionalGasLimit * count + callbackGasLimit,
            count
        );
    }

    /**
     * Chainlink calls this function when the random numbers are generated.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomNums) internal override {
        _setRandomNumbers(requestId, randomNums);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[46] private __gap;
}