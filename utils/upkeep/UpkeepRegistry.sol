// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";
import "./KeeperCompatibleViewInterface.sol";

//import "hardhat/console.sol";

/**
 * Upkeeps (other contracts) are added to this registry.
 * The registry is periodically checked for all upkeeps whether they need upkeep.
 * If so, they take turn being called individually.
 * This is compatible with Chainlink Keepers.
 */
contract UpkeepRegistry is UUPSUpgradeable, AccessControlEnumerableUpgradeable, PausableUpgradeable, KeeperCompatibleInterface {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    EnumerableSetUpgradeable.AddressSet private _upkeeps; // contracts that need upkeep
    address private _lastUpkeepPerformed; // the upkeep that last performed

    uint256 private _maxUpkeeps; // max number of upkeeps

    /**
     * Emitted when an upkeep is added to this registry.
     */
    event UpkeepAdded(address upkeep);

    /**
     * Emitted when an upkeep is removed from this registry.
     */
    event UpkeepRemoved(address upkeep);

    /**
     * Emitted when an upkeep is performed.
     */
    event UpkeepPerformed(address upkeep, bool success);

    /**
     * Emitted when the max upkeep number is changed.
     */
    event MaxUpkeepsChanged(uint256 maxUpkeeps);

    function initialize(
        uint256 maxUpkeeps_
    ) public virtual initializer {
        require(maxUpkeeps_ > 0, "UpkeepRegistry: Max upkeeps must be more than zero");

        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();
        __Pausable_init();

        // deployer is the admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);

        _maxUpkeeps = maxUpkeeps_;
        _lastUpkeepPerformed = address(0);
    }

    /**
     * Only allow admins to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * Changes the max number of upkeeps.
     */
    function setMaxUpkeeps(uint256 maxUpkeeps_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(maxUpkeeps_ > 0, "UpkeepRegistry: Max upkeeps must be more than zero");
        require(maxUpkeeps_ >= _upkeeps.length(), "UpkeepRegistry: Max upkeeps must be >= current registered upkeeps");
        _maxUpkeeps = maxUpkeeps_;
        emit MaxUpkeepsChanged(maxUpkeeps_);
    }

    function upkeeps() external view returns (address[] memory) {
        return _upkeeps.values();
    }

    /**
     * Admins can add an upkeep to this registry.
     */
    function addUpkeep(address upkeep) external onlyRole(MANAGER_ROLE) {
        _upkeeps.add(upkeep);
        require(_upkeeps.length() <= _maxUpkeeps, "UpkeepRegistry: Cannot add more than max up keeps");
        emit UpkeepAdded(upkeep);
    }

    /**
     * Admins can remove an upkeep from this registry.
     */
    function removeUpkeep(address upkeep) external onlyRole(MANAGER_ROLE) {
        if (!_upkeeps.remove(upkeep))
            revert("UpkeepRegistry: upkeep was not registered");
        if (_lastUpkeepPerformed == upkeep)
            _lastUpkeepPerformed = address(0);
        emit UpkeepRemoved(upkeep);
    }

    /**
     * Returns whether an upkeep in this registry needs upkeep.
     * Goes after the last upkeep that performed one before.
     * Then loops back to the start of the array of upkeeps.
     * Returned performData contains the upkeep address and the performData from the upkeep.
     * Compatible with Chainlink Keepers.
     */
    function checkUpkeep(bytes calldata checkData) external override view returns (bool, bytes memory) {
        if (paused())
            return (false, bytes(""));

        uint256 upkeepsCount = _upkeeps.length();
        uint256 lastUpkeepPerformIndex;
        if (_lastUpkeepPerformed == address(0))
            lastUpkeepPerformIndex = upkeepsCount;
        else {
            for (lastUpkeepPerformIndex=0; lastUpkeepPerformIndex<upkeepsCount; lastUpkeepPerformIndex++) {
                if (_upkeeps.at(lastUpkeepPerformIndex) == _lastUpkeepPerformed)
                    break;
            }
        }

        for (uint256 i=lastUpkeepPerformIndex+1; i<upkeepsCount; i++) {
            KeeperCompatibleViewInterface upkeep = KeeperCompatibleViewInterface(_upkeeps.at(i));
            try upkeep.checkUpkeep(checkData) returns (bool upkeepNeeded, bytes memory performData) {
                if (upkeepNeeded)
                    return (upkeepNeeded, abi.encode(upkeep, performData));
            } catch {
            }
        }
        
        for (uint256 i=0; (i<lastUpkeepPerformIndex+1) && (i<upkeepsCount); i++) {
            KeeperCompatibleViewInterface upkeep = KeeperCompatibleViewInterface(_upkeeps.at(i));
            try upkeep.checkUpkeep(checkData) returns (bool upkeepNeeded, bytes memory performData) {
                if (upkeepNeeded)
                    return (upkeepNeeded, abi.encode(upkeep, performData));
            } catch {
            }
        }

        return (false, bytes(""));
    }

    /**
     * Decodes the upkeep address and their performData and call it.
     */
    function performUpkeep(bytes calldata performData) external override whenNotPaused {
        // console.log("performUpkeep", string(performData));
        (address upkeepAddress, bytes memory upkeepData) = abi.decode(
            performData,
            (address, bytes)
        );

        if (_upkeeps.contains(upkeepAddress)) {
            _lastUpkeepPerformed = upkeepAddress;
            KeeperCompatibleViewInterface upkeep = KeeperCompatibleViewInterface(upkeepAddress);

            try upkeep.performUpkeep(upkeepData) {
                emit UpkeepPerformed(upkeepAddress, true);

                try upkeep.isUpkeepNoLongerNeeded() returns (bool isUpkeepNoLongerNeeded) {
                    if (isUpkeepNoLongerNeeded) {
                        _upkeeps.remove(upkeepAddress);
                        _lastUpkeepPerformed = address(0);
                        emit UpkeepRemoved(upkeepAddress);
                    }
                } catch {
                }
            } catch {// Error(string memory reason) {
                // console.log("performUpkeep failed", reason);
                emit UpkeepPerformed(upkeepAddress, false);
            }
        } else {
            revert("UpkeepRegistry: Upkeep is not registered");
        }
    }

    /**
     * Convenient function for testing.
     */
    function checkAndPerformUpkeep() external {
        (bool upkeepNeeded, bytes memory performData) = this.checkUpkeep(bytes(""));
        if (upkeepNeeded)
            this.performUpkeep(performData);
    }

    /**
     * Pause for emergency use only.
     */
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /**
     * Unpause after emergency is gone.
     */
    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}