//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ERC20Bannable is ERC20, Ownable {
    mapping(address => bool) internal bannedAddresses;

    event AddressBanned(address wallet);
    event AddressUnbanned(address wallet);

    /**
     * Bans an address from transferring tokens in and out.
     */
    function banAddress(address wallet) public onlyOwner {
        bannedAddresses[wallet] = true;
        emit AddressBanned(wallet);
    }

    /**
     * Unbans an address from transferring tokens in and out.
     */
    function unbanAddress(address wallet) public onlyOwner {
        bannedAddresses[wallet] = false;
        emit AddressUnbanned(wallet);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the from and to addresses are not banned.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!bannedAddresses[from], "ERC20Bannable: sender address is banned");
        require(!bannedAddresses[to], "ERC20Bannable: recipient address is banned");
    }
}
