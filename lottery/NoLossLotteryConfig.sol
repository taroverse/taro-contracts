// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../utils/TwoStageOwnable.sol";
import "../utils/rng/IRandomNumberGenerator.sol";
import "./NoLossLotteryStorage.sol";

/**
 * Storage contract for lottery configs vars.
 */
abstract contract NoLossLotteryConfig is TwoStageOwnableUpgradeable, NoLossLotteryStorage {
    // configs
    string private _name; // name of the lottery
    uint256 private _endTime; // end time in unix timestamp in secs
    IERC20Upgradeable private _paymentToken; // the ERC20 token to get payment from
    uint256 private _pricePerTicket; // price of payment token per ticket
    uint256 private _maxTicketsPerPlayer; // max tickets each player can buy
    uint256[] private _tieredTickets; // an array of tickets tiers
    uint256[] private _tieredAwards; // an array of award tiers
    address private _paymentTarget; // when lottery is closed, send the payments from winners to this address
    IRandomNumberGenerator private _randomNumberGenerator; // the random number generator to use
    address private _manager; // the manager that can indirectly buy, claim, refund for players

    /**
     * Emitted when the max tickets per player changes.
     */
    event MaxTicketsPerPlayerChanged(uint256 count);

    /**
     * Emitted when the payment target changes.
     */
    event PaymentTargetChanged(address target);

    /**
     * Emitted when the random number generator changes.
     */
    event RandomNumberGeneratorChanged(address rng);

    /**
     * Emitted when the manager changes.
     */
    event ManagerChanged(address manager);

    function __NoLossLotteryConfig_init(
        string memory name_,
        uint256 endTime_,
        IERC20Upgradeable paymentToken_,
        uint256 pricePerTicket_,
        uint256 maxTicketsPerPlayer_,
        uint256[] memory tieredTickets_,
        uint256[] memory tieredAwards_,
        address paymentTarget_,
        address rng_,
        address manager_,
        address owner_
    ) internal onlyInitializing {
        __TwoStageOwnable_init(owner_);
        __NoLossLotteryStorage_init();
        __NoLossLotteryConfig_init_unchained(
            name_, endTime_, paymentToken_, pricePerTicket_, maxTicketsPerPlayer_,
            tieredTickets_, tieredAwards_, paymentTarget_, rng_, manager_, owner_
        );
    }

    function __NoLossLotteryConfig_init_unchained(
        string memory name_,
        uint256 endTime_,
        IERC20Upgradeable paymentToken_,
        uint256 pricePerTicket_,
        uint256 maxTicketsPerPlayer_,
        uint256[] memory tieredTickets_,
        uint256[] memory tieredAwards_,
        address paymentTarget_,
        address rng_,
        address manager_,
        address
    ) internal onlyInitializing {
        require(endTime_ > block.timestamp, "NoLossLotteryConfig: End time must be later than now");
        require(address(paymentToken_) != address(0), "NoLossLotteryConfig: Payment token is needed");
        require(pricePerTicket_ > 0, "NoLossLotteryConfig: Price per ticket must not be zero");
        require(paymentTarget_ != address(0), "NoLossLotteryConfig: Payment target is needed");
        require(rng_ != address(0), "NoLossLotteryConfig: Random number generator must not be zero address");
        require(tieredTickets_.length > 0, "NoLossLotteryConfig: Must have at least one tier");
        require(tieredTickets_.length == tieredAwards_.length, "NoLossLotteryConfig: Ticket and award tiers must match");
        require(tieredTickets_[0] == 0, "NoLossLotteryConfig: First tier tickets must be zero");

        for (uint256 i=1; i<tieredTickets_.length; i++) {
            require(tieredTickets_[i] > tieredTickets_[i-1], "NoLossLotteryConfig: Incorrect tiered tickets config");
            require(tieredAwards_[i] > tieredAwards_[i-1], "NoLossLotteryConfig: Incorrect tiered awards config");
        }

        _name = name_;
        _endTime = endTime_;
        _paymentToken = paymentToken_;
        _pricePerTicket = pricePerTicket_;
        _maxTicketsPerPlayer = maxTicketsPerPlayer_;
        _tieredTickets = tieredTickets_;
        _tieredAwards = tieredAwards_;
        _paymentTarget = paymentTarget_;
        _randomNumberGenerator = IRandomNumberGenerator(rng_);
        _manager = manager_;
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function endTime() public view override returns (uint256) {
        return _endTime;
    }

    function paymentToken() public view override returns (IERC20Upgradeable) {
        return _paymentToken;
    }

    function pricePerTicket() public view returns (uint256) {
        return _pricePerTicket;
    }

    function maxTicketsPerPlayer() public view returns (uint256) {
        return _maxTicketsPerPlayer;
    }

    function setMaxTicketsPerPlayer(uint256 maxTicketsPerPlayer_) public onlyOwner {
        _maxTicketsPerPlayer = maxTicketsPerPlayer_;

        emit MaxTicketsPerPlayerChanged(maxTicketsPerPlayer_);
    }

    function tieredTickets() public view returns (uint256[] memory) {
        return _tieredTickets;
    }

    function tieredAwards() public view returns (uint256[] memory) {
        return _tieredAwards;
    }

    function setPaymentTarget(address target) public onlyOwner {
        require(target != address(0), "NoLossLotteryConfig: Payment target must not be zero address");
        _paymentTarget = target;
        emit PaymentTargetChanged(target);
    }

    function paymentTarget() public view returns (address) {
        return _paymentTarget;
    }

    function randomNumberGenerator() public view returns (IRandomNumberGenerator) {
        return _randomNumberGenerator;
    }

    function setRandomNumberGenerator(address rng_) public onlyOwner {
        require(rng_ != address(0), "NoLossLotteryConfig: Random number generator must not be zero address");
        _randomNumberGenerator = IRandomNumberGenerator(rng_);
        emit RandomNumberGeneratorChanged(rng_);
    }

    function manager() public view returns (address) {
        return _manager;
    }

    function setManager(address manager_) public onlyOwner {
        _manager = manager_;
        emit ManagerChanged(manager_);
    }

    modifier onlyManager {
        require(msg.sender == _manager, "NoLossLotteryConfig: Only manager can call this function");
        _;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[40] private __gap;
}