// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "./IRandomNumberGenerator.sol";
import "./VRFConsumerBaseV2Upgradeable.sol";

import "hardhat/console.sol";

/**
 * Logic contract for random number generator.
 * This uses an access control mechanism.  Only callers/senders with requester role can generate random numbers.
 * Random numbers are not generated synchronously.
 * The caller makes a request using requestRandomNumbers(),
 * then calls isRequestComplete() to check if it is completed later.
 * If completed, then call randomNumbers() to get them.
 *
 * Derived contracts must implement _requestRandomNumbers() to start/do the work to generate random numbers.
 * And when the random numbers are generated, call _setRandomNumbers().
 */
abstract contract RandomNumberGeneratorLogic is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IRandomNumberGenerator {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant REQUESTER_ROLE = keccak256("REQUESTER_ROLE");

    mapping(uint256 => uint256[]) private _randomNumbers; // request ID to generated random numbers
    mapping(uint256 => bool) private _requestsCompleted; // request ID to whether completed
    mapping(uint256 => address) private _callbacks; // request ID to callback contracts

    function __RandomNumberGeneratorLogic_init() internal onlyInitializing {
        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __RandomNumberGeneratorLogic_init_unchained();
    }

    function __RandomNumberGeneratorLogic_init_unchained() internal onlyInitializing {
        // deployer is the admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);
    }

    /**
     * Only allow admins to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * Allow the manager to add a requester.
     */
    function addRequester(address requester) external onlyRole(MANAGER_ROLE) {
        _grantRole(REQUESTER_ROLE, requester);
    }

    /**
     * Request to generate random numbers and returns the request ID.
     * Only callers/senders with the requester role can make this call.
     */
    function requestRandomNumbers(uint32 count) external virtual override returns (uint256 requestId) {
        return requestRandomNumbers(count, address(0), 0);
    }

    /**
     * Request to generate random numbers and returns the request ID.
     * If the callback is not zero address, it must be an instance of VRFConsumerBaseV2Upgradeable.
     * Only callers/senders with the requester role can make this call.
     */
    function requestRandomNumbers(uint32 count, address callback, uint32 callbackGasLimit) public virtual override onlyRole(REQUESTER_ROLE) returns (uint256 requestId) {
        require(count > 0, "RandomNumberGeneratorLogic: Request count must be more than zero");

        requestId = _requestRandomNumbers(count, callbackGasLimit);
        if (_callbacks[requestId] != callback)
            _callbacks[requestId] = callback;

        emit RandomNumbersRequested(requestId, count, msg.sender);
    }

    /**
     * Derived contracts must implement this function to start/do the work to generate random numbers.
     */
    function _requestRandomNumbers(uint32 count, uint32 callbackGasLimit) internal virtual returns (uint256 requestId);

    /**
     * Derived contracts call this function to set the random numbers after they are generated.
     * Each request can only call this once.
     */
    function _setRandomNumbers(uint256 requestId, uint256[] memory randomNums) internal {
        require(!_requestsCompleted[requestId], "RandomNumberGeneratorLogic: Random numbers already set");

        _randomNumbers[requestId] = randomNums;
        _requestsCompleted[requestId] = true;

        emit RequestCompleted(requestId, randomNums);

        VRFConsumerBaseV2Upgradeable callback = VRFConsumerBaseV2Upgradeable(_callbacks[requestId]);
        if (address(callback) != address(0)) {
            try callback.rawFulfillRandomWords(requestId, randomNums) {
            } catch {
                emit RequestCallbackFailed(requestId, address(callback));
            }
        }
    }

    /**
     * Returns whether the request is complete.
     */
    function isRequestComplete(uint256 requestId) external virtual override view returns (bool isCompleted) {
        return _requestsCompleted[requestId];
    }

    /**
     * Returns the generated random numbers for a request.
     */
    function randomNumbers(uint256 requestId) external virtual override view returns (uint256[] memory randomNums) {
        require(_requestsCompleted[requestId], "RandomNumberGeneratorLogic: Random numbers are not generated");
        return _randomNumbers[requestId];
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
