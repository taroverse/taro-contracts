// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

/**
 * Rewards logic based on how much and how long is staked.
 * The reward rate (in tokens per second) is constant for the whole system during the reward duration.
 * Each player's reward is proportional to their staked out of the whole system's staked amount.
 * The rewards are accumulated per second.
 * Players can claim their rewards any time.
 *
 * Modified from: https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol
 */
contract TaroNFTStakingRewards is Initializable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /* ========== STATE VARIABLES ========== */

    IERC20Upgradeable public rewardsToken;
    uint256 public periodFinish;            // the unix time of the next reward finish period
    uint256 public rewardRate;              // reward for all players per sec
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /* ========== EVENTS ========== */

    event RewardSet(uint256 rewardAmount, uint256 newDuration);

    /* ========== INITIALIZERS ========== */
    function __TaroNFTStakingRewards_init(
        IERC20Upgradeable rewardsToken_
    ) internal onlyInitializing {
        __TaroNFTStakingRewards_init_unchained(rewardsToken_);
    }

    function __TaroNFTStakingRewards_init_unchained(
        IERC20Upgradeable rewardsToken_
    ) internal onlyInitializing {
        require(address(rewardsToken_) != address(0), "Rewards Token cannot be zero address");

        rewardsToken = IERC20Upgradeable(rewardsToken_);
        periodFinish = 0;
        rewardRate = 0;
        lastUpdateTime = 0;
        rewardPerTokenStored = 0;
    }

    /* ========== VIEWS ========== */

    function totalSupply() internal view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) internal view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * For internal calculation and debugging, no meaning to user.
     */
    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored.add(
                lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(_totalSupply)
            );
    }

    /**
     * Returns how much reward the player has earned now.
     */
    function earned(address account) public view returns (uint256) {
        return _balances[account].mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
    }

    /**
     * Returns the current reward per token per second.
     */
    function rewardRatePerToken() public view returns (uint256) {
        if (block.timestamp >= periodFinish)
            return 0;
        if (_totalSupply == 0)
            return rewardRate;
        return rewardRate.mul(1e18).div(_totalSupply);
    }

    /**
     * Returns the current reward per second for a player.
     */
    function rewardRateOf(address account) public view returns (uint256) {
        return _balances[account].mul(rewardRatePerToken()).div(1e18);
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _stake(uint256 amount) internal {
        require(amount > 0, "Cannot stake 0");
        _updateReward(msg.sender);

        _totalSupply = _totalSupply.add(amount);
        _balances[msg.sender] = _balances[msg.sender].add(amount);
    }

    function _unstake(uint256 amount) internal {
        require(amount > 0, "Cannot withdraw 0");
        _updateReward(msg.sender);

        _totalSupply = _totalSupply.sub(amount);
        _balances[msg.sender] = _balances[msg.sender].sub(amount);
    }

    function _claimReward() internal {
        _updateReward(msg.sender);

        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.safeTransfer(msg.sender, reward);
        }
    }

    // function _exit() internal {
    //     _unstake(_balances[msg.sender]);
    //     _claimReward();
    // }

    function _updateReward(address account) private {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * Sets the new reward amount and duration, and where to transfer the funds from/to.
     * If the left over reward amount from previous duration is less than
     * the new reward amount, it will transfer the needed amount from the reward pool.
     * If the left over reward amount from previous duration is more than
     * the new reward amount, it will transfer the unneeded amount to the reward pool.
     */
    function _setReward(address rewardPool, uint256 rewardAmount, uint256 rewardsDuration_) internal {
        _updateReward(address(0));

        // figure out how much was left over from before
        uint256 leftOver = 0;
        if (block.timestamp < periodFinish) {
            uint256 remaining = periodFinish.sub(block.timestamp);
            leftOver = remaining.mul(rewardRate);
        }

        rewardRate = rewardAmount.div(rewardsDuration_);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration_);
        emit RewardSet(rewardAmount, rewardsDuration_);

        if (rewardAmount > leftOver) {
            // if need to add more, then transfer in
            uint256 transferAmount = rewardAmount - leftOver;
            rewardsToken.safeTransferFrom(rewardPool, address(this), transferAmount);
        
        } else if (rewardAmount < leftOver) {
            // if left over has more than needed, then transfer out
            uint256 transferAmount = leftOver - rewardAmount;
            rewardsToken.safeTransferFrom(address(this), rewardPool, transferAmount);
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[41] private __gap;
}