// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../../utils/TwoStageOwnable.sol";
import "../../utils/ArrayUtils.sol";
import "../TaroNFT.sol";
import "../TaroNFTConstants.sol";
import "./TaroNFTMiningPower.sol";
import "./TaroNFTStakingRewards.sol";

import "hardhat/console.sol";

/**
 *
 * Encoding of the set ID is:
 *   first 160 bits: staker address
 *   next 48 bits: current block number
 *   next 8 bits: current index of the passed in staking heroes
 *   next 32 bits: some hash
 *   last 8 bits: rarity of the staking hero
 */
contract TaroNFTStaking is UUPSUpgradeable, TwoStageOwnableUpgradeable, PausableUpgradeable,
    ERC1155HolderUpgradeable, TaroNFTMiningPower, TaroNFTStakingRewards {

    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using ArrayUtils for uint256[];

    TaroNFT private _taroNft; // the address of the taro nft contract

    struct StakedHero {
        uint256 heroTokenId;
        uint256[] itemTokenIds;
    }

    mapping(uint256 => StakedHero) _stakedHeroes;
    mapping(address => uint256[]) _playerSetIds;

    event HeroStaked(address indexed player, uint256 stakedId, uint256 indexed heroTokenId);
    event HeroUnstaked(address indexed player, uint256 stakedId, uint256 indexed heroTokenId);

    event HeroConfigured(address indexed player, uint256 stakedId, uint256 indexed heroTokenId, uint256[] itemTokenIds);

    function initialize(
        TaroNFT taroNft_,
        IERC20Upgradeable taroToken
    ) public virtual initializer {
        require(address(taroNft_) != address(0), "TaroNFTStaking: Taro NFT address must not be zero");
        __UUPSUpgradeable_init();
        __TwoStageOwnable_init(msg.sender);
        __Pausable_init();
        __TaroNFTMiningPower_init();
        __TaroNFTStakingRewards_init(taroToken);

        _taroNft = TaroNFT(taroNft_);
    }

    /**
     * Only allow owner to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}

    function miningPowerOf(address player) external view returns (uint256) {
        return balanceOf(player);
    }

    function totalMiningPowerOfAll() external view returns (uint256) {
        return totalSupply();
    }

    function stakedSetIdsOf(address player) external view returns (uint256[] memory) {
        return _playerSetIds[player];
    }

    function stakedSet(uint256 setId) external view returns (
        uint256 setMiningPower,
        uint256[] memory stakedIds, StakedHero[] memory stakedHeroes, uint256[] memory heroMiningPowers
    ) {
        setMiningPower = 0;

        uint256 setHeroCount = 0;
        for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
            if (_stakedHeroes[setId | j].heroTokenId != 0) {
                setHeroCount++;
            }
        }

        stakedIds = new uint256[](setHeroCount);
        stakedHeroes = new StakedHero[](setHeroCount);
        heroMiningPowers = new uint256[](setHeroCount);

        uint256 stakedIdIndex = 0;
        for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
            uint256 stakedId = setId | j;
            StakedHero memory stakedHero = _stakedHeroes[stakedId];
            if (stakedHero.heroTokenId != 0) {
                stakedIds[stakedIdIndex] = stakedId;
                stakedHeroes[stakedIdIndex] = stakedHero;
                uint256 miningPower = heroWithItemsMiningPower(stakedHero.heroTokenId, stakedHero.itemTokenIds);
                heroMiningPowers[stakedIdIndex] = miningPower;
                setMiningPower += miningPower;
                stakedIdIndex++;
            }
        }

        if (_isFullBonusSet(setId))
            setMiningPower += SET_BONUS_MINING_POWER * ONE_MANTISSA;
    }

    function stakedSetsOf(address player) external view returns (
        uint256[] memory setIds, uint256[] memory setMiningPowers,
        uint256[][] memory stakedIds, StakedHero[][] memory stakedHeroes, uint256[][] memory heroMiningPowers
    ) {
        setIds = _playerSetIds[player];
        uint256 setCount = setIds.length;

        setMiningPowers = new uint256[](setCount);
        stakedIds = new uint256[][](setCount);
        stakedHeroes = new StakedHero[][](setCount);
        heroMiningPowers = new uint256[][](setCount);

        for (uint256 i=0; i<setCount; i++) {
            uint256 setId = setIds[i];

            uint256 setHeroCount = 0;
            for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
                if (_stakedHeroes[setId | j].heroTokenId != 0) {
                    setHeroCount++;
                }
            }

            stakedIds[i] = new uint256[](setHeroCount);
            stakedHeroes[i] = new StakedHero[](setHeroCount);
            heroMiningPowers[i] = new uint256[](setHeroCount);
    
            uint256 stakedIdIndex = 0;
            for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
                uint256 stakedId = setId | j;
                StakedHero memory stakedHero = _stakedHeroes[stakedId];
                if (stakedHero.heroTokenId != 0) {
                    stakedIds[i][stakedIdIndex] = stakedId;
                    stakedHeroes[i][stakedIdIndex] = stakedHero;
                    uint256 miningPower = heroWithItemsMiningPower(stakedHero.heroTokenId, stakedHero.itemTokenIds);
                    heroMiningPowers[i][stakedIdIndex] = miningPower;
                    setMiningPowers[i] += miningPower;
                    stakedIdIndex++;
                }
            }

            if (_isFullBonusSet(setId))
                setMiningPowers[i] += SET_BONUS_MINING_POWER * ONE_MANTISSA;
        }
    }

    function stakedHeroCountOf(address player) public view returns (uint256) {
        uint256[] memory setIds = _playerSetIds[player];
        uint256 setCount = setIds.length;

        uint256 heroCount = 0;
        for (uint256 i=0; i<setCount; i++) {
            uint256 setId = setIds[i];

            for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
                if (_stakedHeroes[setId | j].heroTokenId != 0) {
                    heroCount++;
                }
            }
        }

        return heroCount;
    }

    function stakedTokenCountOf(address player) public view returns (uint256) {
        uint256[] storage setIds = _playerSetIds[player];
        uint256 setCount = setIds.length;

        uint256 count = 0;
        for (uint256 i=0; i<setCount; i++) {
            uint256 setId = setIds[i];

            for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
                StakedHero storage stakedHero = _stakedHeroes[setId | j];
                if (stakedHero.heroTokenId != 0) {
                    count += 1 + stakedHero.itemTokenIds.length;
                }
            }
        }

        return count;
    }

    function stakedTokenIdsOf(address player) public view returns(uint256[] memory tokenIds) {
        tokenIds = new uint256[](stakedTokenCountOf(player));

        uint256[] storage setIds = _playerSetIds[player];
        uint256 setCount = setIds.length;

        uint256 index = 0;
        for (uint256 i=0; i<setCount; i++) {
            uint256 setId = setIds[i];

            for (uint8 j=0; j<TaroNFTConstants.HERO_RARITY_COUNT; j++) {
                StakedHero memory stakedHero = _stakedHeroes[setId | j];
                if (stakedHero.heroTokenId != 0) {
                    tokenIds[index++] = stakedHero.heroTokenId;
                    for (uint256 k=0; k<stakedHero.itemTokenIds.length; k++) {
                        tokenIds[index++] = stakedHero.itemTokenIds[k];
                    }
                }
            }
        }
    }

    /**
     * Stake heroes.
     *
     * @param setIds the IDs of sets, or 0 for a new set, or 1 to use the previous set
     * @param heroTokenIds the hero token IDs to stake
     */
    function stakeHeroes(
        uint256[] calldata setIds, uint256[] calldata heroTokenIds
    ) external whenNotPaused {
        require(setIds.length == heroTokenIds.length, "TaroNFTStaking: sets and heroes arrays must have equal length");
        require(heroTokenIds.length > 0, "TaroNFTStaking: must stake more than zero hero");
        require(heroTokenIds.length < 256, "TaroNFTStaking: must stake less than 256 heroes at a time");

        uint256 allPlayersMiningPower = totalSupply();
        uint256 diffMiningPower = 0;
        uint256 prevSetId = 0;
        uint16 setHeroNameId = 0;

        for (uint256 i=0; i<setIds.length; i++) {
            uint256 setId = setIds[i];
            uint256 heroTokenId = heroTokenIds[i];
            (uint8 nameId, , uint8 rarity, uint8 level) = TaroNFTConstants.decodeHeroId(heroTokenId);    

            // check if hero is valid
            uint256 miningPower = _heroMiningPower(rarity, level);
            require(miningPower > 0, "TaroNFTStaking: hero is not valid");

            bool isNewSet = false;

            // if set ID is 1, then use the previous set
            if (setId == 1) {
                setId = prevSetId;
                require(setHeroNameId == nameId, "TaroNFTStaking: must stake same hero in the set");
            } else {
                // if set ID is 0, then it's a new set
                if (setId == 0) {
                    // calculate the new set id and add it to player's list
                    setId = ((uint256(uint160(msg.sender)) << 96)
                        | (block.number << 48) | (i << 40)
                        | (uint256(keccak256(abi.encode(diffMiningPower, allPlayersMiningPower, gasleft()))) << 224 >> 216)
                    );
                    _playerSetIds[msg.sender].push(setId);
                    isNewSet = true;
                } else {
                    // if passing in a set ID, the first 160 bits must be the player's address
                    require(address(uint160(setId >> 96)) == msg.sender, "TaroNFTStaking: set belongs to another address");
                }

                // get the hero current in the set
                setHeroNameId = _getSetHeroNameId(setId);
                if (isNewSet) {
                    require(setHeroNameId == type(uint16).max, "TaroNFTStaking: set already exists");
                    setHeroNameId = nameId;
                } else {
                    require(setHeroNameId != type(uint16).max, "TaroNFTStaking: set doesn't exist");
                    require(setHeroNameId == nameId, "TaroNFTStaking: must stake same hero in the set");
                }

                prevSetId = setId;
            }

            uint256 stakedId = setId | rarity;
            StakedHero storage stakedHero = _stakedHeroes[stakedId];

            // check if the rarity slot is not already staked
            require(stakedHero.heroTokenId == 0, "TaroNFTStaking: a hero of same rarity is already staked in set");

            // save it
            stakedHero.heroTokenId = heroTokenId;

            // check set bonus
            if ((rarity <= TaroNFTConstants.HERO_RARITY_EPIC_ID) && _isFullBonusSet(setId))
                miningPower += SET_BONUS_MINING_POWER * ONE_MANTISSA;

            diffMiningPower += miningPower;

            // event
            emit HeroStaked(msg.sender, stakedId, heroTokenId);
        }

        //TODO: add mining power to staking contract
        _stake(diffMiningPower);

        // transfer token last to prevent reentrancy
        _taroNft.safeBatchOneEachTransferFrom(msg.sender, address(this), heroTokenIds, "");
    }

    function _isFullBonusSet(uint256 setId) private view returns (bool) {
        for (uint8 i=0; i<=TaroNFTConstants.HERO_RARITY_EPIC_ID; i++) {
            if (_stakedHeroes[setId | i].heroTokenId == 0)
                return false;
        }
        return true;
    }

    function _getSetHeroNameId(uint256 setId) private view returns (uint16) {
        for (uint8 i=0; i<=TaroNFTConstants.HERO_RARITY_LEGENDARY_ID; i++) {
            uint256 heroTokenId = _stakedHeroes[setId | i].heroTokenId;
            if (heroTokenId != 0) {
                (uint8 nameId, , ,) = TaroNFTConstants.decodeHeroId(heroTokenId);
                return nameId;
            }
        }
        return type(uint16).max;
    }

    function unstakeHeroes(uint256[] calldata stakedIds) external whenNotPaused {
        uint256 heroCount = stakedIds.length; 
        require(heroCount > 0, "TaroNFTStaking: must unstake more than zero heroes");

        address player = msg.sender;

        uint256[] storage playerSetIds = _playerSetIds[player];
        StakedHero[] memory stakedHeroes = new StakedHero[](heroCount);
        uint256 diffMiningPower = 0;

        for (uint256 i=0; i<heroCount; i++) {
            uint256 stakedId = stakedIds[i];
            require(address(uint160(stakedId >> 96)) == player, "TaroNFTStaking: set belongs to another address");
            uint256 setId = stakedId >> 8 << 8;

            StakedHero memory stakedHero = _stakedHeroes[stakedId];
            stakedHeroes[i] = stakedHero;

            require(stakedHero.heroTokenId != 0, "TaroNFTStaking: hero is not staked");

            uint8 rarity = uint8(stakedId & 0xff);
            bool hadFullBonusSet = (rarity <= TaroNFTConstants.HERO_RARITY_EPIC_ID) && _isFullBonusSet(setId);

            // remove it
            delete _stakedHeroes[stakedId];

            uint256 miningPower = heroWithItemsMiningPower(stakedHero.heroTokenId, stakedHero.itemTokenIds);
            diffMiningPower += miningPower;

            // if there is no more hero left in set, then remove the set too
            if (_getSetHeroNameId(setId) == type(uint16).max) {
                (uint256 setIdIndex, ) = playerSetIds.indexOf(setId);
                uint256 playerSetIdCount = playerSetIds.length;
                if (setIdIndex != (playerSetIdCount - 1)) {
                    playerSetIds[setIdIndex] = playerSetIds[playerSetIdCount - 1];
                }
                playerSetIds.pop();
            } else {
                // check set bonus
                if (hadFullBonusSet) {
                    diffMiningPower += SET_BONUS_MINING_POWER * ONE_MANTISSA;
                }
            }

            // event
            emit HeroUnstaked(player, stakedId, stakedHero.heroTokenId);
        }

        //TODO: remove mining power to staking contract
        _unstake(diffMiningPower);

        // transfer tokens last to prevent reentrancy
        for (uint256 i=0; i<heroCount; i++) {
            _taroNft.safeTransferFrom(address(this), player, stakedHeroes[i].heroTokenId, 1, "");
            if (stakedHeroes[i].itemTokenIds.length > 0)
                _taroNft.safeBatchOneEachTransferFrom(address(this), player, stakedHeroes[i].itemTokenIds, "");
        }
    }

    function configStakedHero(
        uint256 stakedId,
        uint256[] calldata newItemTokenIds
    ) external whenNotPaused {
        address player = msg.sender;
        require(address(uint160(stakedId >> 96)) == player, "TaroNFTStaking: set belongs to another address");

        StakedHero storage stakedHero = _stakedHeroes[stakedId];

        uint256 heroTokenId = stakedHero.heroTokenId;
        require(heroTokenId != 0, "TaroNFTStaking: hero is not staked");

        uint256 miningPower = heroWithItemsMiningPower(heroTokenId, newItemTokenIds);
        require(miningPower > 0, "TaroNFTStaking: hero or items not valid");

        uint256 prevMiningPower = heroWithItemsMiningPower(heroTokenId, stakedHero.itemTokenIds);

        // figure out which items to remove and which to add
        uint256[] memory itemTokenIdsToRemove = stakedHero.itemTokenIds.difference(newItemTokenIds);
        uint256[] memory itemTokenIdsToAdd = newItemTokenIds.difference(stakedHero.itemTokenIds);
        require(itemTokenIdsToRemove.length > 0 || itemTokenIdsToAdd.length > 0, "TaroNFTStaking: no changes");

        // save it
        stakedHero.itemTokenIds = newItemTokenIds;

        //TODO: change mining power to staking contract
        if (miningPower > prevMiningPower) {
            uint256 diff = miningPower - prevMiningPower;
            _stake(diff);
        } else if (miningPower < prevMiningPower) {
            uint256 diff = prevMiningPower - miningPower;
            _unstake(diff);
        }

        // event
        emit HeroConfigured(player, stakedId, heroTokenId, newItemTokenIds);

        // transfer tokens last to prevent reentrancy
        if (itemTokenIdsToAdd.length > 0)
            _taroNft.safeBatchOneEachTransferFrom(player, address(this), itemTokenIdsToAdd, "");
        if (itemTokenIdsToRemove.length > 0)
            _taroNft.safeBatchOneEachTransferFrom(address(this), player, itemTokenIdsToRemove, "");
    }

    function claimReward() external whenNotPaused {
        _claimReward();
    }

    function setInitialRewardStrategy(
        uint256 startBlockNumber,
        uint256 perBlockReward_,
        uint256 duration
    ) external onlyOwner returns (bool succeed) {
        return _setInitialRewardStrategy(startBlockNumber, perBlockReward_, duration);
    }

    function setRewardStrategy(uint256 perBlockReward_, uint256 duration) external onlyOwner returns (bool succeed) {
        return _setRewardStrategy(perBlockReward_, duration);
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
    uint256[49] private __gap; //TODO
}
