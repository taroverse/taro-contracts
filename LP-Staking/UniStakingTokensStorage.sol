// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

abstract contract UniStakingTokensStorageUpgradeable is Initializable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 private _rewardPool;
    uint256 private _rewardSupply;
    uint256 private _totalSupply;
    IERC20Upgradeable private _rewardsToken;
    IERC20Upgradeable private _stakingToken;
    uint256 private _feePool;
    uint256 private _feeScheduleTimeScale;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _claimed;
    mapping(address => uint256) private _rewards;
    mapping(address => uint256) private _lastStakeTime;
    mapping(address => uint256) private _weightedAvgStakeTime;
    mapping(address => uint256) private _feesPaid;

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

    function stakingToken() public view returns (IERC20Upgradeable) {
        return _stakingToken;
    }

    function feePool() public view returns (uint256) {
        return _feePool;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function rewardOf(address account) public view returns (uint256) {
        return _rewards[account];
    }

    function lastStakeTimeOf(address account) public view returns (uint256) {
        return _lastStakeTime[account];
    }

    function weightedAvgStakeTimeOf(address account) public view returns (uint256) {
        return _weightedAvgStakeTime[account];
    }

    function feesPaidOf(address account) public view returns (uint256) {
        return _feesPaid[account];
    }

    // returns in % * 100
    function getUnstakeFeePercent(address account) public view returns(uint256) {
        uint256 weightedAvgStakeTime = weightedAvgStakeTimeOf(account);
        uint256 scaledTimeSinceWeightedAvgStakeTime = (block.timestamp - weightedAvgStakeTime) / _feeScheduleTimeScale;

        if (scaledTimeSinceWeightedAvgStakeTime < 1) // 1 hr
            return 800;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24) // 24 hrs
            return 400;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 3) // 3 days
            return 200;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7) // 1 week
            return 100;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7 * 2) // 2 week
            return 50;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7 * 4) // 4 weeks
            return 40;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7 * 6) // 6 weeks
            return 30;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7 * 8) // 8 weeks
            return 20;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7 * 10) // 10 weeks
            return 10;
        else if (scaledTimeSinceWeightedAvgStakeTime < 24 * 7 * 12) // 12 weeks
            return 5;
        else
            return 1;
    }

    function __UniStakingTokensStorage_init(
        IERC20Upgradeable rewardsToken_, IERC20Upgradeable stakingToken_, uint256 feeScheduleTimeScale_
    ) internal onlyInitializing {
        _rewardsToken = rewardsToken_;
        _stakingToken = stakingToken_;
        _feeScheduleTimeScale = feeScheduleTimeScale_;
    }

    function _onMint(address account, uint256 amount) internal virtual {}
    function _onBurn(address account, uint256 amount) internal virtual {}

    function _stake(address account, uint256 amount) internal {
        _stakingToken.safeTransferFrom(account, address(this), amount);

        uint256 prevBalance = _balances[account];
        uint256 weightedAvgStakeTime = _weightedAvgStakeTime[account];

        _balances[account] = _balances[account].add(amount);
        _totalSupply = _totalSupply.add(amount);

        _lastStakeTime[account] = block.timestamp;

        // weighted avg stake time = now - (now - prev weighted avg stake time) * prev balance / new balance
        _weightedAvgStakeTime[account] = block.timestamp.sub((block.timestamp.sub(weightedAvgStakeTime)).mul(prevBalance).div(_balances[account]));

        _onMint(account, amount);
    }

    function _unstake(address account, uint256 amount) internal {
        uint256 fee = amount.mul(getUnstakeFeePercent(account)).div(10000);
        uint256 netUnstake = amount.sub(fee);
        _feePool = _feePool.add(fee);

        _balances[account] = _balances[account].sub(amount);
        _feesPaid[account] = _feesPaid[account].add(fee);
        _totalSupply = _totalSupply.sub(amount);

        _stakingToken.safeTransfer(account, netUnstake);

        _onBurn(account, amount);
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

    function _transferCollectedFees(address collector) internal {
        _stakingToken.safeTransfer(collector, _feePool);
        _feePool = 0;
   }

   /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[37] private __gap;
}
