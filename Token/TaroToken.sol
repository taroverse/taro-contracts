//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC20Bannable.sol";

contract TaroToken is ERC20Bannable, ERC20Burnable {
    constructor() ERC20("Taroverse Token", "TARO") {
        _mint(msg.sender, 2e27); // 2 bil tokens
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override (ERC20, ERC20Bannable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
