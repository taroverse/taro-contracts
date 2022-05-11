// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./INoLossLottery.sol";

interface INoLossLotteryERC1155 is INoLossLottery {

    function awardToken() external view returns (IERC1155);

    function awardTokenId() external view returns (uint256);

    function awardsPerTicket() external view returns (uint256);
}