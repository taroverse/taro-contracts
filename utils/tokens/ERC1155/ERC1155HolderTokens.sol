// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of holder's tokens.
 */
abstract contract ERC1155HolderTokens is ERC1155 {
    using EnumerableSet for EnumerableSet.UintSet;

    mapping(address => EnumerableSet.UintSet) private _holderTokens; // holder to token ids

    /**
     * Returns a list of token IDs that the `holder` owns.
     *
     * Some of these tokens may have a balance of zero.
     * It is up to the UI to filter out those tokens.
     */
    function tokenIdsOf(address holder) public view returns (uint256[] memory tokenIds) {
        return _holderTokens[holder].values();
    }

    /**
     * Returns a list of token IDs and their balances that the `holder` owns.
     *
     * Some of these tokens may have a balance of zero.
     * It is up to the UI to filter out those tokens.
     */
    function tokenIdsAndBalancesOf(address holder) public view returns (
        uint256[] memory tokenIds, uint256[] memory balances
    ) {
        tokenIds = _holderTokens[holder].values();
        
        uint256 tokenCount = tokenIds.length;
        balances = new uint256[](tokenCount);
        
        unchecked {
            for (uint256 i=0; i<tokenCount; i++) {
                balances[i] = balanceOf(holder, tokenIds[i]);
            }
        }
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     *
     * This hook is called before any token transfer.
     * If the balance of a token for `to` is zero before the transfer,
     * that token ID is added to that holder's list of tokens owned.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != to) {
            EnumerableSet.UintSet storage toTokenIds = _holderTokens[to];

            for (uint256 i = 0; i < ids.length; ) {
                if (amounts[i] > 0) {
                    uint256 id = ids[i];

                    if ((to != address(0)) && (balanceOf(to, id) == 0)) {
                        toTokenIds.add(id);
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @dev See {ERC1155-_afterTokenTransfer}.
     *
     * This hook is called after any token transfer.
     * If the balance of a token for `from` is zero after the transfer,
     * that token ID is removed from that holder's list of tokens owned.
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._afterTokenTransfer(operator, from, to, ids, amounts, data);

        if (from != to) {
            EnumerableSet.UintSet storage fromTokenIds = _holderTokens[from];

            for (uint256 i = 0; i < ids.length; ) {
                if (amounts[i] > 0) {
                    uint256 id = ids[i];

                    if ((from != address(0)) && (balanceOf(from, id) == 0)) {
                        fromTokenIds.remove(id);
                    }
                }

                unchecked {
                    ++i;
                }
            }
        }
    }
}
