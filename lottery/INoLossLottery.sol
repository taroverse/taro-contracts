// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface INoLossLottery {
    enum LotteryState {
        CREATED,
        STARTED,
        CLOSED,
        GENERATING_RANDOM_NUMBER,
        FINALIZED
    }

    /**
     * Emitted when the state of the lottery changes.
     */
    event StateChanged(LotteryState newState);

    /**
     * Emitted when a player buys tickets.
     */
    event TicketsBought(address indexed player, uint256 count);

    /**
     * Emitted when a player claims their winning tickets.
     */
    event TicketsClaimed(address indexed player, uint256 winningTicketCount);

    /**
     * Emitted when a player refunds their non-winning tickets.
     */
    event TicketsRefunded(address indexed player, uint256 nonWinningTicketCount);

    function name() external view returns (string memory);

    function endTime() external view returns (uint256);

    /**
     * State of the lottery.
     */
    function state() external view returns (LotteryState);

    /**
     * The payment token.
     */
    function paymentToken() external view returns (IERC20Upgradeable);

    /**
     * The number of tickets sold.
     */
    function ticketCount() external view returns (uint256);

    /**
     * Player buys a specific number of tickets.
     */
    function buyTickets(uint256 count) external;

    /**
     * Buys a specific number of tickets for player.
     * Only the lottery manager can call.
     */
    function buyTicketsFor(address player, uint256 count) external returns (uint256);

    /**
     * Number of tickets the player bought.
     */
    function ticketCountOf(address player) external view returns (uint256);

    /**
     * Number of winning tickets the player has.
     */
    function winningTicketCountOf(address player) external view returns (uint256);

    /**
     * Number of non-winning tickets the player has.
     */
    function nonwinningTicketCountOf(address player) external view returns (uint256);

    /**
     * The number of winning tickets claimed so far.
     */
    function ticketsClaimedCount() external view returns (uint256);

    /**
     * Whether the player can claim any winning tickets.
     */
    function canClaimTickets(address player) external view returns (bool);

    /**
     * Whether the player claimed their winning tickets.
     */
    function ticketsClaimed(address player) external view returns (bool);

    /**
     * Player claims their winning tickets.
     */
    function claimTickets() external returns (uint256);

    /**
     * Claims awards for winning tickets for player.
     * Only the lottery manager can call.
     */
    function claimTicketsFor(address player) external returns (uint256);

    /**
     * Whether the player can refund any nonwinning tickets.
     */
    function canRefundTickets(address player) external view returns (bool);

    /**
     * Whether the player refunded their nonwinning tickets.
     */
    function ticketsRefunded(address player) external view returns (bool);

    /**
     * Player refunds their nonwinning tickets.
     */
    function refundTickets() external returns (uint256);

    /**
     * Refunds non-winning tickets for player.
      * Only the lottery manager can call.
    */
    function refundTicketsFor(address player) external returns (uint256);
}