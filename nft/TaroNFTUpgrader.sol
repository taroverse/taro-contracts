// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../utils/TwoStageOwnable.sol";
import "./TaroNFT.sol";
import "./TaroNFTConstants.sol";

/**
 * This contract is used to upgrade Taro hero and item NFTs.
 * Some hero/item NFTs can be upgraded and have certain upgrade requirements.
 * When upgrading, the original and requirement NFTs are burned,
 * and the next level of the original NFT is minted.
 */
contract TaroNFTUpgrader is UUPSUpgradeable, TwoStageOwnableUpgradeable, PausableUpgradeable {

    TaroNFT private _taroNft; // the address of the taro nft contract

    /**
     * mapping for level to the upgrade requirements for an epic hero:
     * the encoding is divided into levels, with each level using
     * 6 bytes (12 hex digits) to represent the number of each rarity requirement and whether needs to be same class
     */
    bytes internal constant EPIC_LEVEL_TO_UPGRADE_REQUIREMENTS = hex"020000000000010100000000010200000000020200000001030000000000020200000000030200000000020201000000030101000001050000000000020300000000040300000000030302000000040202000001060100000000030400000000050400000000040403000000050303000001";

    /**
     * mapping for level to the upgrade requirements for a legendary hero:
     * uses same encoding as for epic
     */
    bytes internal constant LEGENDARY_LEVEL_TO_UPGRADE_REQUIREMENTS = hex"020000000000010100000000010200000000020200000001030000000000020200000000030200000000020201000000030101000001050000000000020300000000040300000000030302000000040202000001060100000000030400000000050400000000040403000000050303010001";

    uint8 internal constant ITEM_UPGRADE_REQUIREMENT_COUNT = 4;

    /**
     * Emitted a hero is upgraded.
     */
    event HeroUpgraded(address indexed player, uint256 indexed previousTokenId, uint256 indexed upgradedTokenId);

    /**
     * Emitted an item is upgraded.
     */
    event ItemUpgraded(address indexed player, uint256 indexed previousTokenId, uint256 indexed upgradedTokenId);

    function initialize(
        address taroNft_
    ) public virtual initializer {
        require(taroNft_ != address(0), "TaroChestOpener: Taro NFT address must not be zero");
        __UUPSUpgradeable_init();
        __TwoStageOwnable_init(msg.sender);
        __Pausable_init();

        _taroNft = TaroNFT(taroNft_);
    }

    /**
     * Only allow owner to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * Upgrades a hero NFT at tokenId with requirements.
     * The tokenId and the requirements will be burned,
     * and the next level of the same hero will be minted.
     * The requirements passed in must match exactly as requirements needed.
     *
     * @param tokenId the hero token ID
     * @param requirements the requirements
     */
    function upgradeHero(uint256 tokenId, uint256[] calldata requirements) external whenNotPaused {
        // get the hero attributes first
        (uint8 series, uint8 nameId, uint8 classId, uint8 rarity, uint8 level) = TaroNFTConstants.decodeHeroId(tokenId);
        
        // check whether upgradeable
        (bool upgradeable, uint8[] memory rarityRequirements, bool sameClass) = _heroUpgradeRequirements(rarity, level);
        require(upgradeable, "TaroNFTUpgrader: the hero is not upgradeable");

        uint reqCount = requirements.length;

        // check requirements are exact
        for (uint256 i=0; i<reqCount; i++) {
            (, , uint8 reqClassId, uint8 reqRarity, ) = TaroNFTConstants.decodeHeroId(requirements[i]);
            require(!sameClass || classId == reqClassId, "TaroNFTUpgrader: all heroes must be in the same class");

            require(rarityRequirements[reqRarity] > 0, "TaroNFTUpgrader: unnecessary requirement is supplied");
            rarityRequirements[reqRarity]--;
        }

        // check no missing requirements
        for (uint256 i=0; i<TaroNFTConstants.HERO_RARITY_COUNT; i++) {
            require(rarityRequirements[i] == 0, "TaroNFTUpgrader: missing requirements");
        }

        uint256 upgradedTokenId = TaroNFTConstants.encodeHeroId(series, nameId, rarity, level + 1);
        emit HeroUpgraded(msg.sender, tokenId, upgradedTokenId);

        // burn token and requirements
        _taroNft.burn(msg.sender, tokenId, 1);
        _taroNft.burnBatchOneEach(msg.sender, requirements);

        // mint upgraded token
         _taroNft.mint(msg.sender, upgradedTokenId, 1, "");
    }

    /**
     * Returns the upgrade requirements for rarity and level hero.
     * @dev Less gas to use bytes constant.
     *
     * @param rarity the rarity, 0 (common), 1 (uncommon), 2 (rare), 3 (epic), 4 (legendary)
     * @param level the level, 1 to 20
     * @return upgradeable whether the hero is upgradeable
     * @return rarityRequirements the number of requirements per rarity
     * @return sameClass whether all the requirements need to be in the same class
     */
    function _heroUpgradeRequirements(uint8 rarity, uint8 level) internal pure
    returns (bool upgradeable, uint8[] memory rarityRequirements, bool sameClass) {
        rarityRequirements = new uint8[](TaroNFTConstants.HERO_RARITY_COUNT);
        if (level > 0) {
            uint256 levelIndex = (level- 1) * (TaroNFTConstants.HERO_RARITY_COUNT + 1);
            bytes memory req;

            if (rarity == TaroNFTConstants.HERO_RARITY_EPIC_ID) {
                req = EPIC_LEVEL_TO_UPGRADE_REQUIREMENTS;
            } else if (rarity == TaroNFTConstants.HERO_RARITY_LEGENDARY_ID) {
                req = LEGENDARY_LEVEL_TO_UPGRADE_REQUIREMENTS;
            } else {
                return (false, rarityRequirements, false);
            }

            if (levelIndex < req.length) {
                for (uint256 i=0; i<TaroNFTConstants.HERO_RARITY_COUNT; i++) {
                    rarityRequirements[i] = uint8(req[levelIndex + i]);
                }
                sameClass = (uint8(req[levelIndex + TaroNFTConstants.HERO_RARITY_COUNT]) == 1);
                return (true, rarityRequirements, sameClass);
            }        
        }

        return (false, rarityRequirements, false);
    }

    /**
     * External function to return the upgrade requirements for a hero.
     */
    function heroUpgradeRequirements(uint256 tokenId) external pure
    returns (bool upgradeable, uint8[] memory rarityRequirements, bool sameClass) {
        (, , , uint8 rarity, uint8 level) = TaroNFTConstants.decodeHeroId(tokenId);
        return _heroUpgradeRequirements(rarity, level);
    }


    /**
     * Upgrades an item NFT at tokenId with requirements.
     * The tokenId and the requirements will be burned,
     * and the next level of the same item will be minted.
     * The requirements passed in must match exactly as requirements needed.
     *
     * @param tokenId the item token ID
     * @param requirements the requirements
     */
    function upgradeItem(uint256 tokenId, uint256[] calldata requirements) external whenNotPaused {
        // get item attributes first
        (uint8 classId, uint8 level) = TaroNFTConstants.decodeItemId(tokenId);
        
        // check whether upgradeable
        require(level > 0 && level < TaroNFTConstants.ITEM_MAX_LEVEL, "TaroNFTUpgrader: the item is not upgradeable");

        // check requirements are exact
        uint reqCount = requirements.length;
        require(reqCount == ITEM_UPGRADE_REQUIREMENT_COUNT, "TaroNFTUpgrader: requirements not matching");
        
        for (uint256 i=0; i<reqCount; i++) {
            require(tokenId == requirements[i], "TaroNFTUpgrader: all items must be in same class and level");
        }

        address from = msg.sender;

        uint256 upgradedTokenId = TaroNFTConstants.encodeItemId(classId, level + 1);
        emit ItemUpgraded(from, tokenId, upgradedTokenId);

        // burn token and requirements
        _taroNft.burn(from, tokenId, ITEM_UPGRADE_REQUIREMENT_COUNT + 1);

        // mint upgraded token
         _taroNft.mint(from, upgradedTokenId, 1, "");
    }

    /**
     * Returns the upgrade requirements for an item.
     */
    function itemUpgradeRequirements(uint256 tokenId) external pure
    returns (bool upgradeable, uint8 sameClassLevelRequirementCount) {
        (, uint8 level) = TaroNFTConstants.decodeItemId(tokenId);
        if (level > 0 && level < TaroNFTConstants.ITEM_MAX_LEVEL)
            return (true, ITEM_UPGRADE_REQUIREMENT_COUNT);
        return (false, 0);
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
    uint256[49] private __gap;
}
