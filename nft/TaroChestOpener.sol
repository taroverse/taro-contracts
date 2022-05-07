// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../utils/TwoStageOwnable.sol";
import "../utils/rng/IRandomNumberGenerator.sol";
import "../utils/rng/VRFConsumerBaseV2Upgradeable.sol";
import "../utils/UniformRandomNumber.sol";
import "./TaroNFT.sol";
import "./TaroNFTConstants.sol";

/**
 * Contract to unlock and open hero and item NFT chests.
 * Player approves this contract to transfer their TaroNFT tokens first.
 * Then requests to unlock some hero or item chests.
 * The chests are transferred from the player to this contract at this time.
 * The contract asks the RNG to generate a random number per request.
 * Once the RNG has generated a random number for the request,
 * the player can open the chests for that request.
 * The chests are burned and the new heroes/items are minted and transferred to the player.
 */
contract TaroChestOpener is
    UUPSUpgradeable, TwoStageOwnableUpgradeable, PausableUpgradeable,
    ERC1155HolderUpgradeable, VRFConsumerBaseV2Upgradeable {

    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    TaroNFT private _taroNft; // the address of the taro nft contract
    uint256 private _maxChestsPerUnlock; // the max number of chests to unlock at once
    IRandomNumberGenerator private _randomNumberGenerator; // the random number generator to use

    struct ChestOpenRequest {
        address player;
        uint256 tokenId;
        uint256 count;
        uint256 timestamp;
    }
    mapping(uint256 => ChestOpenRequest) private _requests; // request id to request struct

    mapping(address => EnumerableSetUpgradeable.UintSet) private _playerRequests; // a list of each player's request ids

    /**
     * Emitted when the player unlocks some chests with the tokenId.
     * The requestId is used later for check and open the chests.
     */
    event UnlockChestsRequested(uint256 requestId, address indexed player, uint256 indexed tokenId, uint256 count);

    /**
     * Emitted the chests for a request are unlocked.
     */
    event ChestsUnlocked(uint256 requestId, address indexed player, uint256 indexed tokenId, uint256 count);

    /**
     * Emitted the chests for a request are opened.
     */
    event ChestsOpened(uint256 requestId, address indexed player, uint256 indexed tokenId, uint256 count, uint256[] tokens);

    event RandomNumberGeneratorChanged(address rng);
    event MaxChestsPerUnlockChanged(uint256 maxChestsPerUnlock);

    function initialize(
        address taroNft_,
        uint256 maxChestsPerUnlock_,
        address rng_
    ) public virtual initializer {
        require(taroNft_ != address(0), "TaroChestOpener: Taro NFT address must not be zero");
        require(maxChestsPerUnlock_ > 0, "TaroChestOpener: max chests per unlock must not be zero");
        __UUPSUpgradeable_init();
        __TwoStageOwnable_init(msg.sender);
        __Pausable_init();
        __ERC1155Holder_init();
        __VRFConsumerBaseV2_init(rng_);

        _taroNft = TaroNFT(taroNft_);
        _maxChestsPerUnlock = maxChestsPerUnlock_;
        _randomNumberGenerator = IRandomNumberGenerator(rng_);
    }

    /**
     * Only allow owner to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function randomNumberGenerator() public view returns (IRandomNumberGenerator) {
        return _randomNumberGenerator;
    }

    /**
     * For the owner to change the RNG if something were to happen to the current RNG.
     */
    function setRandomNumberGenerator(address rng_) public onlyOwner {
        require(rng_ != address(0), "TaroChestOpener: Random number generator must not be zero address");
        _randomNumberGenerator = IRandomNumberGenerator(rng_);
        emit RandomNumberGeneratorChanged(rng_);
    }

    /**
     * For owner to set the max number of chests per unlock request.
     */
    function setMaxChestsPerUnlock(uint256 maxChestsPerUnlock_) external onlyOwner {
        require(maxChestsPerUnlock_ > 0, "TaroChestOpener: max chests per unlock must not be zero");
        _maxChestsPerUnlock = maxChestsPerUnlock_;
        emit MaxChestsPerUnlockChanged(maxChestsPerUnlock_);
    }

    function maxChestsPerUnlock() external view returns (uint256) {
        return _maxChestsPerUnlock;
    }

    /**
     * Player calls this to unlock a number of hero chests.
     * Must call approve on the TaroNFT contract first.
     */
    function unlockHeroChests(uint256 count) external whenNotPaused {
        _unlockChests(TaroNFTConstants.HERO_CHEST_ID, count);
    }

    /**
     * Player calls this to unlock a number of item chests.
     * Must call approve on the TaroNFT contract first.
     */
    function unlockItemChests(uint256 count) external whenNotPaused {
        _unlockChests(TaroNFTConstants.ITEM_CHEST_ID, count);
    }

    /**
     * Starts the request to unlock chests, and transfers chests to this contract.
     */
    function _unlockChests(uint256 tokenId, uint256 count) private {
        require(count > 0, "TaroChestOpener: count must be more than zero");
        require(count <= _maxChestsPerUnlock, "TaroChestOpener: count must be less than max chests per unlock");

        address from = msg.sender;

        uint256 requestId = _randomNumberGenerator.requestRandomNumbers(1, address(this), 100000);

        // save request info
        ChestOpenRequest storage request = _requests[requestId];
        request.player = from;
        request.tokenId = tokenId;
        request.count = count;
        request.timestamp = block.timestamp;

        // save to player's requests list
        _playerRequests[from].add(requestId);

        emit UnlockChestsRequested(requestId, from, tokenId, count);

        // transfer to this contract
        _taroNft.safeTransferFrom(from, address(this), tokenId, count, "");
    }

    /**
     * Called by the RNG, and we just emit an event here.
     */
    function fulfillRandomWords(uint256 requestId, uint256[] memory) internal virtual override {
        ChestOpenRequest storage request = _requests[requestId];
        emit ChestsUnlocked(requestId, request.player, request.tokenId, request.count);
    }

    /**
     * Returns whether the request is done and can open the chests.
     */
    function canOpenChests(uint256 requestId) external view returns (bool) {
        if (paused())
            return false;
        return _randomNumberGenerator.isRequestComplete(requestId);
    }

    /**
     * Returns a list of unlock chests request IDs for a player.
     */
    function unlockChestsRequestIdsOf(address player) external view returns (uint256[] memory) {
        return _playerRequests[player].values();
    }

    /**
     * Returns a list of unlock chests requests and their info for a player.
     */
    function unlockChestsRequestsOf(address player) external view returns (
        uint256[] memory requestIds, uint256[] memory tokenIds,
        uint256[] memory counts, uint256[] memory timestamps, bool[] memory canOpen
    ) {
        requestIds = _playerRequests[player].values();
        uint256 requestCount = requestIds.length;

        tokenIds = new uint256[](requestCount);
        counts = new uint256[](requestCount);
        timestamps = new uint256[](requestCount);
        canOpen = new bool[](requestCount);

        for (uint256 i=0; i<requestCount; i++) {
            ChestOpenRequest storage request = _requests[requestIds[i]];
            tokenIds[i] = request.tokenId;
            counts[i] = request.count;
            timestamps[i] = request.timestamp;
            canOpen[i] = _randomNumberGenerator.isRequestComplete(requestIds[i]);
        }
    }

    /**
     * Opens the chests for a request.
     * Checks to see if it's from the same player first.
     * Then randomly picks the heroes or items.
     * Removes the request from the player's list of unlocking requests.
     * Burns chests and mints new heroes/items to the player.
     */
    function openChests(uint256 requestId) external whenNotPaused {
        address from = msg.sender;
        ChestOpenRequest storage request = _requests[requestId];

        require(request.player == from, "TaroChestOpener: request is not from same user");

        uint256 count = request.count;
        uint256 tokenId = request.tokenId;

        uint256[] memory tokens;

        if (tokenId == TaroNFTConstants.HERO_CHEST_ID) {
            tokens = _pickHeroes(from, count, _randomNumberGenerator.randomNumbers(requestId)[0]);
        } else if (tokenId == TaroNFTConstants.ITEM_CHEST_ID) {
            tokens = _pickItems(from, count, _randomNumberGenerator.randomNumbers(requestId)[0]);
        } else {
            revert("TaroChestOpener: cannot open invalid chest ID");
        }

        // delete the request
        delete _requests[requestId];
        _playerRequests[from].remove(requestId);
        
        emit ChestsOpened(requestId, from, tokenId, count, tokens);

        // burn then mint
        _taroNft.burn(address(this), tokenId, count);
        _taroNft.mintBatchOneEach(from, tokens, "");
    }

    /**
     * Randomly picks some heroes.
     * For each hero, we need to pick the name id and rarity.
     * They are always at level 1.
     */
    function _pickHeroes(address player, uint256 count, uint256 randomNumber) private pure
    returns (uint256[] memory tokens) {
        tokens = new uint256[](count);

        // figure out the hero name and rarity
        for (uint32 i=0; i<count; i++) {
            // since the hero name count is small, we will use a uniform random number
            uint8 nameId = uint8(
                UniformRandomNumber.rand(
                    TaroNFTConstants.HEROES_NAME_COUNT,
                    uint256(keccak256(abi.encode(randomNumber, count*654321, i, player)))
                )
            );

            uint256 rarityRandNum = UniformRandomNumber.rand(
                TaroNFTConstants.HERO_RARITY_LEGENDARY_THRESHOLD,
                uint256(keccak256(abi.encode(randomNumber, player, count, i*123456)))
            );
            uint8 rarity;
            if (rarityRandNum < TaroNFTConstants.HERO_RARITY_COMMON_THRESHOLD)
                rarity = 0;
            else if (rarityRandNum < TaroNFTConstants.HERO_RARITY_UNCOMMON_THRESHOLD)
                rarity = 1;
            else if (rarityRandNum < TaroNFTConstants.HERO_RARITY_RARE_THRESHOLD)
                rarity = 2;
            else if (rarityRandNum < TaroNFTConstants.HERO_RARITY_EPIC_THRESHOLD)
                rarity = 3;
            else
                rarity = 4;

            tokens[i] = TaroNFTConstants.encodeHeroId(0, nameId, rarity, 1);
        }
    }

    /**
     * Randomly picks some items.
     * For each item, we just need to pick the class id.
     * They are all at level 1.
     */
    function _pickItems(address player, uint256 count, uint256 randomNumber) private pure
    returns (uint256[] memory tokens) {
        tokens = new uint256[](count);

        // figure out the hero name and rarity
        for (uint32 i=0; i<count; i++) {
            // since the class count is small, we will use a uniform random number
            uint8 classId = uint8(
                UniformRandomNumber.rand(
                    TaroNFTConstants.ITEM_CLASS_COUNT,
                    uint256(keccak256(abi.encode(randomNumber, count*456, i*123, player)))
                )
            );

            tokens[i] = TaroNFTConstants.encodeItemId(classId, 1);
        }
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
    uint256[45] private __gap;
}
