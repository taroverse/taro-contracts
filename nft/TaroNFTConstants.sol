// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TaroNFTConstants {
    uint256 internal constant HERO_CHEST_ID = 0;
    uint256 internal constant ITEM_CHEST_ID = 1;
    // reserved: 2 to 0xff

    uint256 internal constant HEROES_FIRST_ID =  0x0000100;
    uint256 internal constant HEROES_LAST_ID =   0xfffff00;

    uint256 internal constant ITEMS_FIRST_ID = 0x010000000;
    uint256 internal constant ITEMS_LAST_ID =  0xff0000000;

    uint256 internal constant HEROES_NAME_COUNT = 59;

    // name ID to class ID mapping
    // the name ID is the index in the bytes array.
    // every byte (2 hex digits) is a different name ID.
    // the value of the byte is the class ID: 0 (Assassin), 1 (Diviner), 2 (Guardian), 3 (Mage), 4 (Sniper), 5 (Warrior)
    bytes internal constant NAME_IDS_2_CLASS_IDS = hex"0000000000000001010101010101010102020202020202020202030303030303030303030304040404050505050505050505050505050505050505";

    uint256 internal constant HERO_RARITY_COUNT = 5;
    uint8 internal constant HERO_RARITY_COMMON_ID    = 0;
    uint8 internal constant HERO_RARITY_UNCOMMON_ID  = 1;
    uint8 internal constant HERO_RARITY_RARE_ID      = 2;
    uint8 internal constant HERO_RARITY_EPIC_ID      = 3;
    uint8 internal constant HERO_RARITY_LEGENDARY_ID = 4;

    // chances for getting a specific rarity
    uint256 internal constant HERO_RARITY_COMMON_THRESHOLD =     50000000; // 50%
    uint256 internal constant HERO_RARITY_UNCOMMON_THRESHOLD =   85000000; // 35% more than last
    uint256 internal constant HERO_RARITY_RARE_THRESHOLD =       97000000; // 12% more than last
    uint256 internal constant HERO_RARITY_EPIC_THRESHOLD =       99500000; // 2.5% more than last
    uint256 internal constant HERO_RARITY_LEGENDARY_THRESHOLD = 100000000; // 0.5% more than last

    uint256 internal constant ITEM_CLASS_COUNT = 5;

    uint8 internal constant ITEM_MAX_LEVEL = 10;

    /**
     * Encodes the hero attributes into its token ID.
     * 
     * @param nameId the ID of the hero name, 0 to 59
     * @param rarity the rarity, 0 (common), 1 (uncommon), 2 (rare), 3 (epic), 4 (legendary)
     * @param level the level, 1 to 20
     * @return tokenId the token ID
     */
    function encodeHeroId(uint8 nameId, uint8 rarity, uint8 level) internal pure returns (uint256) {
        return uint256(nameId) * 0x100000 + uint256(rarity) * 0x10000 + uint256(level)* 0x100;
    }

    /**
     * Decodes the hero token ID and returns its attributes.
     * 
     * @param id the hero token ID
     * @return nameId the ID of the hero name, 0 to 59
     * @return classId the ID of the class name, 0 (Assassin), 1 (Diviner), 2 (Guardian), 3 (Mage), 4 (Sniper), 5 (Warrior)
     * @return rarity the rarity, 0 (common), 1 (uncommon), 2 (rare), 3 (epic), 4 (legendary)
     * @return level the level, 1 to 20
     */
    function decodeHeroId(uint256 id) internal pure returns (uint8 nameId, uint8 classId, uint8 rarity, uint8 level) {
        nameId = uint8((id & 0xff00000) / 0x100000);
        rarity = uint8((id & 0xf0000) / 0x10000);
        level = uint8((id & 0xff00) / 0x100);
        classId = uint8(NAME_IDS_2_CLASS_IDS[uint256(nameId)]);
    }

    /**
     * Encodes the item attributes into its token ID.
     * 
     * @param classId the class ID of the item, 0 to 4
     * @param level the level, 1 to 10
     * @return tokenId the token ID
     */
    function encodeItemId(uint8 classId, uint8 level) internal pure returns (uint256) {
        return uint256(classId) * 0x100000000 + uint256(level)* 0x10000000;
    }

    /**
     * Decodes the item token ID and returns its attributes.
     * 
     * @param id the item token ID
     * @return classId the ID of the class name, 0 (Armor), 1 (Boots), 2 (Crystal), 3 (Potion), 4 (Sword)
     * @return level the level, 1 to 10
     */
    function decodeItemId(uint256 id) internal pure returns (uint8 classId, uint8 level) {
        classId = uint8((id & 0xf00000000) / 0x100000000);
        level = uint8((id & 0xf0000000) / 0x10000000);
    }
}
