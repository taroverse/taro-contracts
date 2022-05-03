// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "../utils/tokens/ERC1155/IERC1155Mintable.sol";
import "./INoLossLottery.sol";

/**
 * Manager keeps a list of past lotteries.
 * Players can use manager to claim their winning tickets
 * and refund their nonwinning tickets for a list of lotteries.
 */
contract NoLossLotteryManagerERC1155 is UUPSUpgradeable, AccessControlEnumerableUpgradeable, IERC1155Mintable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    
    address private _token; // the address of the ERC1155 token
    EnumerableSetUpgradeable.AddressSet private _lotteries;

    /**
     * Emitted when a lottery is added.
     */
    event LotteryAdded(address lotter);

    /**
     * Emitted when a player claims tickets for a list of lotteries.
     */
    event TicketsClaimed(address player, address[] lotteries, uint256[] ticketsClaimed);

    /**
     * Emitted when a player refunds tickets for a list of lotteries.
     */
    event TicketsRefunded(address player, address[] lotteries, uint256[] ticketsRefunded);

    function initialize(address token_) public virtual initializer {
        require(token_ != address(0), "NoLossLotteryManagerERC1155: Token address must not be zero");

        __UUPSUpgradeable_init();
        __AccessControlEnumerable_init();

        // deployer is the admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MANAGER_ROLE, msg.sender);

        _token = token_;
    }

    /**
     * Only allow admin to upgrade.
     */
    function _authorizeUpgrade(address) internal override onlyRole(DEFAULT_ADMIN_ROLE) {}

    /**
     * For manager to add a lottery to the list.
     */
    function addLottery(address lottery) external onlyRole(MANAGER_ROLE) {
        _lotteries.add(lottery);
        emit LotteryAdded(lottery);
    }

    /**
     * Requests the mint controller to mint `amount` new tokens for `to`, of token type `id`.
     *
     * Requirements:
     *
     * - the caller must have the allowance to mint the amount of tokens.
     */
    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(_lotteries.contains(msg.sender), "NoLossLotteryManagerERC1155: Only lotteries can mint");
        IERC1155Mintable(_token).mint(to, id, amount, data);
    }

    /**
     * xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(_lotteries.contains(msg.sender), "NoLossLotteryManagerERC1155: Only lotteries can mint");
        IERC1155Mintable(_token).mintBatch(to, ids, amounts, data);
    }

    /**
     * Returns all lotteries.
     */
    function allLotteries() external view returns (address[] memory) {
        return _lotteries.values();
    }

    /**
     * Convenience method to get all lotteries and their names.
     */
    function lotteriesAndNames() external view returns (address[] memory lotteries, string[] memory names) {
        lotteries = _lotteries.values();
        uint256 lotteryCount = lotteries.length;
        names = new string[](lotteryCount);
        
        for (uint256 i=0; i<lotteryCount; i++) {
            INoLossLottery iLottery = INoLossLottery(lotteries[i]);
            names[i] = iLottery.name();
        }
    }

    /**
     * Returns the ticket info of a player for a list of lotteries.
     * If the provided list is empty, it uses the list of lotteries added to this manager.
     */
    function ticketInfoOf(
        address player, address[] memory lotteries
    ) external view returns (
        uint256[] memory ticketsBought, uint256[] memory winningTickets, uint256[] memory nonwinningTickets,
        bool[] memory ticketsClaimed, bool[] memory ticketsRefunded
    ) {
        if (lotteries.length == 0)
            lotteries = _lotteries.values();
        
        uint256 lotteryCount = lotteries.length;

        ticketsBought = new uint256[](lotteryCount);
        winningTickets = new uint256[](lotteryCount);
        nonwinningTickets = new uint256[](lotteryCount);
        ticketsClaimed = new bool[](lotteryCount);
        ticketsRefunded = new bool[](lotteryCount);

        for (uint256 i=0; i<lotteryCount; i++) {
            INoLossLottery iLottery = INoLossLottery(lotteries[i]);
            ticketsBought[i] = iLottery.ticketCountOf(player);
            winningTickets[i] = iLottery.winningTicketCountOf(player);
            ticketsClaimed[i] = iLottery.ticketsClaimed(player);
            ticketsRefunded[i] = iLottery.ticketsRefunded(player);
            if (iLottery.state() == INoLossLottery.LotteryState.FINALIZED)
                nonwinningTickets[i] = ticketsBought[i] - winningTickets[i];
        }
    }

    /**
     * Player buys tickets for a lottery.
     *
     * @dev The total price of the tickets in the payment token will be transferred from the player.
     * So, player must approve at least that much payment token to this contract first.
     */
    function buyTickets(address lottery, uint256 count) external {
        address player = msg.sender;

        require(_lotteries.contains(lottery), "NoLossLotteryManagerERC1155: Lottery must be in list");

        INoLossLottery iLottery = INoLossLottery(lottery);
        uint256 paymentAmount = iLottery.buyTicketsFor(player, count);

        // get payment
        iLottery.paymentToken().safeTransferFrom(player, lottery, paymentAmount);
    }

    /**
     * Player claims their winning tickets for a list of lotteries.
     * If the provided list is empty, it uses the list of lotteries added to this manager.
     */
    function claimTickets(address[] memory lotteries) external {
        address player = msg.sender;

        if (lotteries.length == 0)
            lotteries = _lotteries.values();

        uint256 lotteryCount = lotteries.length;

        uint256[] memory ticketsClaimed = new uint256[](lotteryCount);

        for (uint256 i=0; i<lotteryCount; i++) {
            INoLossLottery iLottery = INoLossLottery(lotteries[i]);
            if (iLottery.canClaimTickets(player))
                ticketsClaimed[i] = iLottery.claimTicketsFor(player);
        }

        emit TicketsClaimed(player, lotteries, ticketsClaimed);
    }

    /**
     * Player refunds their nonwinning tickets for a list of lotteries.
     * If the provided list is empty, it uses the list of lotteries added to this manager.
     */
    function refundTickets(address[] memory lotteries) external {
        address player = msg.sender;

        if (lotteries.length == 0)
            lotteries = _lotteries.values();

        uint256 lotteryCount = lotteries.length;

        uint256[] memory ticketsRefunded = new uint256[](lotteryCount);

        for (uint256 i=0; i<lotteryCount; i++) {
            INoLossLottery iLottery = INoLossLottery(lotteries[i]);
            if (iLottery.canRefundTickets(player))
                ticketsRefunded[i] = iLottery.refundTicketsFor(player);
        }

        emit TicketsRefunded(player, lotteries, ticketsRefunded);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[48] private __gap;
}
