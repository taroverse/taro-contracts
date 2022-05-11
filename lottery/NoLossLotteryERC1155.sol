// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./NoLossLotteryLogic.sol";
import "./INoLossLotteryERC1155.sol";

/**
 * No loss lottery for awarding ERC1155 tokens.
 */
abstract contract NoLossLotteryERC1155 is NoLossLotteryLogic, ERC1155HolderUpgradeable, INoLossLotteryERC1155 {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IERC1155 internal _awardToken;
    uint256 internal _awardTokenId;
    uint256 internal _awardsPerTicket;

    function __NoLossLotteryERC1155_init(
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
        __NoLossLotteryLogic_init(
            name_, endTime_, paymentToken_, pricePerTicket_, maxTicketsPerPlayer_,
            tieredTickets_, tieredAwards_, paymentTarget_, rng_, manager_, owner_
        );
        __ERC1155Holder_init();

        __NoLossLotteryERC1155_init_unchained(
            name_, endTime_, paymentToken_, pricePerTicket_, maxTicketsPerPlayer_,
            tieredTickets_, tieredAwards_, paymentTarget_, rng_, manager_, owner_
        );
    }

    function __NoLossLotteryERC1155_init_unchained(
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
        _awardToken = IERC1155(address(0));
        _awardTokenId = 0;
        _awardsPerTicket = 0;
    }

    function awardToken() public view override returns (IERC1155) {
        return _awardToken;
    }

    function awardTokenId() public view override returns (uint256) {
        return _awardTokenId;
    }

    function awardsPerTicket() public view override returns (uint256) {
        return _awardsPerTicket;
    }

    function _setAwards(
        IERC1155 awardToken_,
        uint256 awardTokenId_,
        uint256 awardsPerTicket_
    ) internal onlyOwner {
        require(address(_awardToken) == address(0), "NoLossLotteryERC1155: Awards are already set");

        require(address(awardToken_) != address(0), "NoLossLotteryERC1155: Award token is needed");
        require(awardsPerTicket_ > 0, "NoLossLotteryERC1155: Award per ticket must be more than 0");

        _awardToken = awardToken_;
        _awardTokenId = awardTokenId_;
        _awardsPerTicket = awardsPerTicket_;
    }

    function _awardsInitialized() internal virtual override view returns (bool) {
        return _awardsPerTicket > 0;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}