// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./NoLossLotteryERC1155.sol";
import "../utils/tokens/ERC1155/IERC1155Mintable.sol";

/**
 * No loss lottery for awarding ERC1155 tokens from an IERC1155Mintable.
 */
contract NoLossLotteryERC1155Minter is NoLossLotteryERC1155 {
    IERC1155Mintable private _minter;

    event AwardsSet(address awardToken, uint256 awardTokenId, uint256 awardsPerTicket, address minter);

    function initialize(
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
    ) public virtual initializer {
        __NoLossLotteryERC1155_init(
            name_, endTime_, paymentToken_, pricePerTicket_, maxTicketsPerPlayer_,
            tieredTickets_, tieredAwards_, paymentTarget_, rng_, manager_, owner_
        );
        
        _minter = IERC1155Mintable(address(0));
    }

    function minter() public view returns (IERC1155Mintable) {
        return _minter;
    }

    function setAwards(
        IERC1155 awardToken_,
        uint256 awardTokenId_,
        uint256 awardsPerTicket_,
        IERC1155Mintable minter_
    ) external onlyOwner {
        _setAwards(awardToken_, awardTokenId_, awardsPerTicket_);

        require(address(minter_) != address(0), "NoLossLotteryERC1155Minter: Minter cannot be zero address");
        _minter = minter_;

        emit AwardsSet(address(awardToken_), awardTokenId_, awardsPerTicket_, address(minter_));
    }

    /**
     * Request mint controller to mint awards to player.
     */
    function _award(address player, uint256 ticketCount) internal virtual override {
        uint256 awardAmount = ticketCount * _awardsPerTicket;
        _minter.mint(player, _awardTokenId, awardAmount, "");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}