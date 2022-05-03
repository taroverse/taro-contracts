// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

abstract contract TaroNFTStakingRewardsStorage is Initializable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private _rewardPool;
    uint256 private _rewardSupply;
    uint256 private _totalSupply;
    IERC20Upgradeable private _rewardsToken;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _claimed;
    mapping(address => uint256) private _rewards;

    function rewardPool() public view returns (uint256) {
        return _rewardPool;
    }
    
    function rewardSupply() public view returns (uint256) {
        return _rewardSupply;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function rewardsToken() public view returns (IERC20Upgradeable) {
        return _rewardsToken;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function rewardOf(address account) public view returns (uint256) {
        return _rewards[account];
    }

    function __TaroNFTStakingRewardsStorage_init(
        IERC20Upgradeable rewardsToken_
    ) internal onlyInitializing {
        __TaroNFTStakingRewardsStorage_init_unchained(rewardsToken_);
    }

    function __TaroNFTStakingRewardsStorage_init_unchained(
        IERC20Upgradeable rewardsToken_
    ) internal onlyInitializing {
        _rewardsToken = rewardsToken_;
    }

    function _stake(address account, uint256 amount) internal {
        _balances[account] = _balances[account].add(amount);
        _totalSupply = _totalSupply.add(amount);
    }

    function _unstake(address account, uint256 amount) internal {
        _balances[account] = _balances[account].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
   }

    function _increaseRewardPool(address owner, uint256 amount) internal {
        _rewardsToken.safeTransferFrom(owner, address(this), amount);
        _rewardSupply = _rewardSupply.add(amount);
        _rewardPool = _rewardPool.add(amount);
    }

    function _reduceRewardPool(address owner, uint256 amount) internal {
        _rewardsToken.safeTransfer(owner, amount);
        _rewardSupply = _rewardSupply.sub(amount);
        _rewardPool = _rewardPool.sub(amount);
    }

    function _addReward(address account, uint256 amount) internal {
        _rewards[account] = _rewards[account].add(amount);
        _rewardPool = _rewardPool.sub(amount);
    }

    function _withdraw(address account, uint256 amount) internal {
        _rewardsToken.safeTransfer(account, amount);
        _claimed[account] = _claimed[account].sub(amount);
    }

    function _claim(address account, uint256 amount) internal {
        _rewards[account] = _rewards[account].sub(amount);
        _rewardSupply = _rewardSupply.sub(amount);
        _claimed[account] = _claimed[account].add(amount);
    }

   /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[37] private __gap; //TODO
}
