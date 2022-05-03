// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../TaroNFTConstants.sol";

/**
 * Contract to determine mining power of heroes and items.
 */
contract TaroNFTMiningPower is Initializable {

    uint256 internal constant COMMON_MINING_POWER = 1;
    uint256 internal constant UNCOMMON_MINING_POWER = 2;
    uint256 internal constant RARE_MINING_POWER = 5;

    // mapping for level to mining power for an epic hero 
    // the encoding is divided into levels, with each level using
    // 2 bytes (4 hex digits) to represent the mining power
    bytes internal constant EPIC_LEVEL_TO_MINING_POWER = hex"000a001e00320046005e00720086009a00ae00ca00de00f20106011a013a014e01620176019401b8";

    // mapping for level to the mining power for a legendary hero
    // uses same encoding as for epic
    bytes internal constant LEGENDARY_LEVEL_TO_MINING_POWER = hex"00320064009600c80109013b016d019f01d102210253028502b702e90348037a03ac03de0410047e";

    uint256 internal constant ITEM_BOOST_PER_LEVEL = 5;

    uint256 internal constant SET_BONUS_MINING_POWER = 100;

    uint256 internal constant ONE_MANTISSA = 10**18;

    function __TaroNFTMiningPower_init() internal onlyInitializing {
        __TaroNFTMiningPower_init_unchained();
    }

    function __TaroNFTMiningPower_init_unchained() internal onlyInitializing {
    }

    /**
     * Returns the mining power for rarity and level hero.
     * @dev Less gas to use bytes constant.
     *
     * @param rarity the rarity, 0 (common), 1 (uncommon), 2 (rare), 3 (epic), 4 (legendary)
     * @param level the level, 1 to 20
     * @return miningPower the mining power with 18 decimal places
     */
    function _heroMiningPower(uint8 rarity, uint8 level) internal pure returns (uint256 miningPower) {
        if (rarity == TaroNFTConstants.HERO_RARITY_COMMON_ID)
            return COMMON_MINING_POWER * ONE_MANTISSA;
        else if (rarity == TaroNFTConstants.HERO_RARITY_UNCOMMON_ID)
            return UNCOMMON_MINING_POWER * ONE_MANTISSA;
        else if (rarity == TaroNFTConstants.HERO_RARITY_RARE_ID)
            return RARE_MINING_POWER * ONE_MANTISSA;
        else {
            uint256 levelIndex = (level- 1) * 2; // 2 bytes per level
            bytes memory bytesArray;

            if (rarity == TaroNFTConstants.HERO_RARITY_EPIC_ID) {
                bytesArray = EPIC_LEVEL_TO_MINING_POWER;
            } else if (rarity == TaroNFTConstants.HERO_RARITY_LEGENDARY_ID) {
                bytesArray = LEGENDARY_LEVEL_TO_MINING_POWER;
            } else {
                return 0;
            }

            if (levelIndex < bytesArray.length)
                return (uint256(uint8(bytesArray[levelIndex])) * 0x100 + uint8(bytesArray[levelIndex+1]))
                    * ONE_MANTISSA;
        }
        
        return 0;
    }

    /**
     * External function to return the mining power for a hero.
     *
     * @param tokenId the hero token ID
     * @return miningPower the mining power with 18 decimal places
     */
    function heroMiningPower(uint256 tokenId) public pure returns (uint256 miningPower) {
        (, , uint8 rarity, uint8 level) = TaroNFTConstants.decodeHeroId(tokenId);
        return _heroMiningPower(rarity, level);
    }

    /**
     * External function to return the mining power boost for an item.
     */
    function itemMiningPowerBoost(uint256 tokenId) public pure returns (uint256 boost) {
        (, uint8 level) = TaroNFTConstants.decodeItemId(tokenId);
        if (level > 0 && level <= TaroNFTConstants.ITEM_MAX_LEVEL)
            return level * ITEM_BOOST_PER_LEVEL;
        return 0;
    }

    /**
     * External function to return the mining power for a hero with items inlaid.
     *
     * @param heroTokenId the hero token ID
     * @param itemTokenIds the inlaid items on the hero
     * @return miningPower the mining power with 18 decimal places
     */
    function heroWithItemsMiningPower(uint256 heroTokenId, uint256[] memory itemTokenIds) public pure returns (uint256 miningPower) {
        miningPower = heroMiningPower(heroTokenId);
        if (miningPower > 0) {
            uint256 boost = 0;
            bool[] memory itemClassInlaid = new bool[](TaroNFTConstants.ITEM_CLASS_COUNT);
            uint256 itemCount = itemTokenIds.length;

            for (uint256 i=0; i<itemCount; i++) {
                (uint8 classId, uint8 level) = TaroNFTConstants.decodeItemId(itemTokenIds[i]);
                if (level == 0 || level > TaroNFTConstants.ITEM_MAX_LEVEL)
                    return 0;
                if (itemClassInlaid[classId])
                    return 0;
                itemClassInlaid[classId] = true;
                boost += level * ITEM_BOOST_PER_LEVEL;
            }

            return miningPower * (100 + boost) / 100;
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}
