// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./INoLossLottery.sol";

/**
 * Storage contract for lottery runtime vars.
 * We are only keeping the number of tickets each player buys, not issuing ID per ticket.
 */
abstract contract NoLossLotteryStorage is Initializable, INoLossLottery {
    LotteryState internal _state; // state of the lottery

    uint256 internal _ticketCount; // total number of tickets sold
    mapping(address => uint256) internal _playerTicketCounts; // player address to ticket count

    mapping(address => bool) internal _playerClaims; // player address to whether they have claimed their winning tickets
    mapping(address => bool) internal _playerRefunds; // player address to whether they have refunded their non-winning tickets

    uint256 internal _ticketsClaimed; // the total number of winning tickets claimed so far

    function __NoLossLotteryStorage_init() internal onlyInitializing {
        __NoLossLotteryStorage_init_unchained();
    }

    function __NoLossLotteryStorage_init_unchained() internal onlyInitializing {
        _ticketCount = 0;
        _ticketsClaimed = 0;
        _setState(LotteryState.CREATED);
    }
    
    function state() public view override returns (LotteryState) {
        return _state;
    }

    function _setState(LotteryState newState) internal {
        _state = newState;
        emit StateChanged(_state);
    }

    function ticketCount() public view override returns (uint256) {
        return _ticketCount;
    }

    function ticketCountOf(address player) public view override returns (uint256) {
        return _playerTicketCounts[player];
    }

    function ticketsClaimedCount() public view override returns (uint256) {
        return _ticketsClaimed;
    }

    /**
     * @dev Mints a specific number of tickets for a player.
     */
    function _mintTickets(address player, uint256 count) internal {
        _playerTicketCounts[player] += count;
        _ticketCount += count;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[44] private __gap;
}