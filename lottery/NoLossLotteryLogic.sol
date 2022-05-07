// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "./NoLossLotteryConfig.sol";
import "../utils/upkeep/KeeperCompatibleViewInterface.sol";
import "../utils/rng/VRFConsumerBaseV2Upgradeable.sol";

/**
 * Logic contract for no loss lottery.
 *   - It allows players to buy tickets.
 *   - It generates random number when the lottery ends.
 *   - Each player's number of winning tickets depends on the random number, their address,
 *     and their share of the total number of tickets sold.
 *   - It allows players to claim awards for winning tickets, get refunds for non-winning tickets.
 */
abstract contract NoLossLotteryLogic is UUPSUpgradeable, NoLossLotteryConfig, PausableUpgradeable, VRFConsumerBaseV2Upgradeable, KeeperCompatibleViewInterface {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    uint256 private _randomNumberRequestId; // the request ID for generating random number
    uint256 private _randomNumber; // the generated random number

    uint256 internal constant ONE_MANTISSA = 10**18;

    uint256 private constant WIN_TO_EXPECT_VARIANCE = 5; // 5%

    function __NoLossLotteryLogic_init(
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
        // init base contracts
        __UUPSUpgradeable_init();
        __NoLossLotteryConfig_init(
            name_, endTime_, paymentToken_, pricePerTicket_, maxTicketsPerPlayer_,
            tieredTickets_, tieredAwards_, paymentTarget_, rng_, manager_, owner_
        );
        __Pausable_init();
        __VRFConsumerBaseV2_init(rng_);

        __NoLossLotteryLogic_init_unchained(
            name_, endTime_, paymentToken_, pricePerTicket_, maxTicketsPerPlayer_,
            tieredTickets_, tieredAwards_, paymentTarget_, rng_, manager_, owner_
        );
    }

    function __NoLossLotteryLogic_init_unchained(
        string memory,
        uint256,
        IERC20Upgradeable,
        uint256,
        uint256,
        uint256[] memory,
        uint256[] memory,
        address,
        address,
        address,
        address
    ) internal onlyInitializing {
    }

    /**
     * Only allow owner to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function isOpen() public view returns (bool) {
        return _state == LotteryState.STARTED && block.timestamp < endTime();
    }

    /**
     * @dev Implement this to return true if the awards are initialized.
     */
    function _awardsInitialized() internal virtual view returns (bool);

    /**
     * State management - conditions to be able to transition to the next state.
     */
    function canTransitState() public view returns (bool) {
        if (paused())
            return false;

        if (_state == LotteryState.CREATED) {
            return endTime() != 0 && _awardsInitialized();
        } else if (_state == LotteryState.STARTED) {
            return block.timestamp >= endTime();
        } else if (_state == LotteryState.CLOSED) {
            return ticketCount() > 0;
        } else if (_state == LotteryState.GENERATING_RANDOM_NUMBER) {
            return randomNumberGenerator().isRequestComplete(_randomNumberRequestId);
        }
        return false;
    }

    /**
     * State management - transition to the next state.
     */
    function transitState() public whenNotPaused {
        require(canTransitState(), "NoLossLotteryLogic: Cannot transit to next state");
        
        if (_state == LotteryState.CREATED) {
            _setState(LotteryState.STARTED);
        } else if (_state == LotteryState.STARTED) {
            _close();
        } else if (_state == LotteryState.CLOSED) {
            _generateRandomNumber();
        } else if (_state == LotteryState.GENERATING_RANDOM_NUMBER) {
            fulfillRandomWords(_randomNumberRequestId, randomNumberGenerator().randomNumbers(_randomNumberRequestId));
        }
    }

    /**
     * Tell UpkeepRegistry whether upkeep is needed - when lottery needs to transit to next state.
     * Compatible with Chainlink Keepers.
     */
    function checkUpkeep(bytes calldata) external override view returns (bool, bytes memory) {
        return (canTransitState(), bytes(""));
    }

    /**
     * UpkeepRegistry calls this to transit to next state.
     * Compatible with Chainlink Keepers.
     */
    function performUpkeep(bytes calldata) external override {
        transitState();
    }

    /**
     * Tell UpkeepRegistry that upkeep is not needed anymore
     * when the lottery is closed and cannot transit to the next state
     * OR when the lottery is finalized.
     */
    function isUpkeepNoLongerNeeded() external view override returns (bool) {
        return (_state == LotteryState.CLOSED && !canTransitState())
            || (_state == LotteryState.FINALIZED);
    }

    /**
     * Close the lottery, and if possible, transition to next state immediately.
     */
    function _close() private {
        _setState(LotteryState.CLOSED);
        if (canTransitState())
            transitState();
    }

    /**
     * Call the random number generator.
     */
    function _generateRandomNumber() private {
        _setState(LotteryState.GENERATING_RANDOM_NUMBER);

        // use an extra 200,000 gas for the fulfillRandomWords() callback
        // _randomNumberRequestId = randomNumberGenerator().requestRandomNumbers(1, address(this), 200000);
        _randomNumberRequestId = randomNumberGenerator().requestRandomNumbers(1);
    }

    /**
     * Compatible with Chainlink VRF.
     */
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal virtual override {
        _randomNumber = randomWords[0];
        _setState(LotteryState.FINALIZED);
    }

    /**
     * Picks the number of winning tickets for a player depending on
     * the generated random number, the player's address,
     * the number of tickets sold, the player's expected winning ticket count.
     * We randomly give 90% to 110% of the the player's expected winning ticket count
     * as the final winning ticket count.
     */
    function winningTicketCountOf(address player) public view override returns (uint256) {
        if (_state != LotteryState.FINALIZED)
            return 0;

        uint256 playerTixCount = _playerTicketCounts[player];
        if (playerTixCount == 0)
            return 0;

        uint256 tixSold = _ticketCount;
        uint256 maxWinTixCount = currentTierAwards();

        // if tickets sold is less than the max winning ticket count, then all of everyone's tickets win
        if (tixSold <= maxWinTixCount)
            return playerTixCount;

        // expected is proportional to player ticket % of total
        uint256 expected = ONE_MANTISSA * playerTixCount * maxWinTixCount / tixSold;

        // give 90% to 110% of expected
        uint256 lowerBound = expected * (100 - WIN_TO_EXPECT_VARIANCE) / 100;
        uint256 upperBound = expected * (100 + WIN_TO_EXPECT_VARIANCE) / 100;
        uint256 diff = upperBound - lowerBound;

        uint256 randomNumber = _randomNumber;
        uint256 playerWinTixCount = uint256(keccak256(abi.encode(randomNumber, player, tixSold*321))) % diff
            + lowerBound;

        // need to round up for some % of the time
        uint256 playerWinTixCountDecimal = playerWinTixCount - playerWinTixCount / ONE_MANTISSA * ONE_MANTISSA;
        uint256 randomDecimal = uint256(keccak256(abi.encode(randomNumber, tixSold*123, player))) % ONE_MANTISSA;
        if (randomDecimal < playerWinTixCountDecimal)
            playerWinTixCount += ONE_MANTISSA;

        playerWinTixCount /= ONE_MANTISSA;

        return MathUpgradeable.min(playerTixCount, playerWinTixCount);
    }

    /**
     * Returns the nonwinning ticket count of a player if it is closed.
     */
    function nonwinningTicketCountOf(address player) public view override returns (uint256) {
        if (_state != LotteryState.FINALIZED)
            return 0;
        return ticketCountOf(player) - winningTicketCountOf(player);
    }

    /**
     * Returns the player's expected winning ticket count in Ether units (1e18).
     * It is proportional to the player ticket count % of total tickets sold
     * and the current tier awards.
     * Eg, if a player's tickets is 10% of all tickets sold,
     * then they should get 10% of awards.
     */
    function expectedWinningTicketCountOf(address player) public view returns (uint256) {
        uint256 playerTixCount = _playerTicketCounts[player];
        if (playerTixCount == 0)
            return 0;

        uint256 tixSold = _ticketCount;
        uint256 maxWinTixCount = currentTierAwards();

        // if tickets sold is less than the max winning ticket count, then all of everyone's tickets win
        if (tixSold <= maxWinTixCount)
            return playerTixCount * ONE_MANTISSA;

        // expected is proportional to player ticket % of total
        return ONE_MANTISSA * playerTixCount * maxWinTixCount / tixSold;
    }

    /**
     * Returns the current ticket and award tier.
     */
    function currentTier() public view returns (uint256) {
        uint256[] memory tiers = tieredTickets();
        uint256 i = 1;
        for (; i<tiers.length && ticketCount() >= tiers[i]; i++) {}
        i--;
        return i;
    }

    /**
     * Returns the award amount for the current tier.
     */
    function currentTierAwards() public view returns (uint256) {
        return tieredAwards()[currentTier()];
    }

    /**
     * Player buys a specific number of tickets.
     * 
     * @dev The total price of the tickets in the payment token will be transferred from the player.
     * So, player must approve at least that much payment token to this contract first.
     */
    function buyTickets(uint256 count) external override {
        address player = msg.sender;

        uint256 paymentAmount = _buyTicketsFor(player, count);

        // get payment
        paymentToken().safeTransferFrom(player, address(this), paymentAmount);
    }

    /**
     * Buys a specific number of tickets for player.
     * Only the lottery manager can call.
     * The manager must transfer the payment amount after this call.
     */
    function buyTicketsFor(address player, uint256 count) external override onlyManager returns (uint256) {
        return _buyTicketsFor(player, count);
    }

    function _buyTicketsFor(address player, uint256 count) private whenNotPaused returns (uint256) {
        require(isOpen(), "NoLossLotteryLogic: Lottery is closed");
        require(count > 0, "NoLossLotteryLogic: Ticket count must be positive");
        require(
            (maxTicketsPerPlayer() == 0) || (ticketCountOf(player) + count <= maxTicketsPerPlayer()),
            "NoLossLotteryLogic: Player ticket limit reached"
        );
        
        // mint the tickets
        _mintTickets(player, count);

        emit TicketsBought(player, count);

        // return the payment amount
        return pricePerTicket() * count;
    }


    /**
     * Whether the player can claim any winning tickets.
     */
    function canClaimTickets(address player) public view override returns (bool) {
        return (!ticketsClaimed(player)) && (winningTicketCountOf(player) > 0);
    }

    /**
     * Whether the player claimed the winning tickets for awards.
     */
    function ticketsClaimed(address player) public view override returns (bool) {
        return _playerClaims[player];
    }

    /**
     * Player claims awards for winning tickets.
     */
    function claimTickets() external override returns (uint256){
        address player = msg.sender;
        return _claimTicketsFor(player);
    }

    /**
     * Claims awards for winning tickets for player.
     * Only the lottery manager can call.
     */
    function claimTicketsFor(address player) external override onlyManager returns (uint256) {
        return _claimTicketsFor(player);
    }

    function _claimTicketsFor(address player) private whenNotPaused returns (uint256) {
        require(_state == LotteryState.FINALIZED, "NoLossLotteryLogic: Lottery is not finalized yet");
        require(!_playerClaims[player], "NoLossLotteryLogic: Player already claimed tickets");

        uint256 winningTicketCount = winningTicketCountOf(player);
        require(winningTicketCount > 0, "NoLossLotteryLogic: Player has no winning tickets");

        _playerClaims[player] = true;
        
        _award(player, winningTicketCount);

        emit TicketsClaimed(player, winningTicketCount);

        // transfer payments from winners to target
        paymentToken().safeTransfer(paymentTarget(), pricePerTicket() * winningTicketCount);

        return winningTicketCount;
    }
    
    /**
     * @dev Implement this to award winners tokens or NFTs.
     */
    function _award(address player, uint256 ticketCount) internal virtual;

    /**
     * Whether the player can refund any nonwinning tickets.
     */
    function canRefundTickets(address player) public view override returns (bool) {
        return (!ticketsRefunded(player)) && (nonwinningTicketCountOf(player) > 0);
    }

    /**
     * Whether the player refunded the non-winning tickets.
     */
    function ticketsRefunded(address player) public view override returns (bool) {
        return _playerRefunds[player];
    }

    /**
     * Player refunds non-winning tickets.
     */
    function refundTickets() external override returns (uint256) {
        address player = msg.sender;
        return _refundTicketsFor(player);
    }

    /**
     * Refunds non-winning tickets for player.
     * Only the lottery manager can call.
     */
    function refundTicketsFor(address player) external override onlyManager returns (uint256) {
        return _refundTicketsFor(player);
    }

    function _refundTicketsFor(address player) private whenNotPaused returns (uint256) {
        require(_state == LotteryState.FINALIZED, "NoLossLotteryLogic: Lottery is not finalized yet");
        require(!_playerRefunds[player], "NoLossLotteryLogic: Player already refunded tickets");

        uint256 ticketCount = ticketCountOf(player);
        uint256 winningTicketCount = winningTicketCountOf(player);
        uint256 nonWinningTicketCount = ticketCount - winningTicketCount;
        require(nonWinningTicketCount > 0, "NoLossLotteryLogic: Player has no non-winning tickets");

        _playerRefunds[player] = true;

        emit TicketsRefunded(player, nonWinningTicketCount);

        paymentToken().safeTransfer(player, pricePerTicket() * nonWinningTicketCount);

        return nonWinningTicketCount;
    }

    /**
     * Pause for emergency use only.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * Unpause after emergency is gone.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}