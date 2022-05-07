// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "../utils/tokens/ERC1155/ERC1155Mintable.sol";
import "../utils/tokens/ERC1155/ERC1155HolderTokens.sol";

/**
 * Taro NFT tokens based of ERC1155.
 *   - Allows addresses with minter roles to mint tokens.
 *   - Allows token holder and addresses with approval to burn tokens.
 *   - Keeps track of each token's supply.
 *   - Keeps track of each holder's tokens and their balances.
 */
contract TaroNFT is ERC1155Mintable, ERC1155Burnable, ERC1155HolderTokens, ERC1155Supply {
    /**
     * Emitted when the URI changes.
     */
    event URISet(string newuri);

    /**
     * Constructor with the URI.
     */
    constructor(string memory uri) ERC1155Mintable(uri) {
    }

    /**
     * Only the admin can change the URI.
     */
    function setURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
        emit URISet(newuri);
    }

    /**
     * Convenient function to transfer a batch with one each.
     */
    function safeBatchOneEachTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        bytes memory data
    ) public virtual {
        uint256 count = ids.length;
        uint256[] memory amounts = new uint256[](count);
        unchecked {
            for (uint256 i=0; i<count; i++) {
                amounts[i] = 1;
            }
        }
        safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * Convenient function to mint a batch with one each.
     */
    function mintBatchOneEach(
        address to,
        uint256[] memory ids,
        bytes memory data
    ) public virtual {
        uint256 count = ids.length;
        uint256[] memory amounts = new uint256[](count);
        unchecked {
            for (uint256 i=0; i<count; i++) {
                amounts[i] = 1;
            }
        }

        mintBatch(to, ids, amounts, data);
    }

    /**
     * Convenient function to burn a batch with one each.
     */
    function burnBatchOneEach(
        address account,
        uint256[] memory ids
    ) public virtual {
        uint256 count = ids.length;
        uint256[] memory amounts = new uint256[](count);
        unchecked {
            for (uint256 i=0; i<count; i++) {
                amounts[i] = 1;
            }
        }

        burnBatch(account, ids, amounts);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override (ERC1155, ERC1155HolderTokens, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override (ERC1155, ERC1155HolderTokens) {
        super._afterTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Mintable, ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}