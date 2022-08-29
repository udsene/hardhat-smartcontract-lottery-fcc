// Raffle Contract
// Enter the lottery (paying some amount)
// Pick a random winner for the lottery (verifiably random)
// Winner to be selected every X minutes -> completely automate
// Chainlink Oracle -> Randomness, Automated Execution (Chainlink Keepers)

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__notEnoughETHEntered();
error Raffle__TransferFail();
error Raffle_isNotOpen();
error Raffle__UpkeepNeededFailed(uint256 currentBalance, uint256 numPlayers, uint256 lotteryState);

/** @title A Sample Raffle Contract
 *  @author Udara Senevirathna
 *  @notice This contract is for creating an untamperable decentralized smart contract
 *  @dev This implements Chainlink VRF v2 and Chainlink Keepers
 */

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type Declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    } // uint256 0 = OPEN, 1 = CALCULATING

    /* State Variables */
    address payable[] private s_players;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    /* Lottery Variables */
    address private s_recentWinner;
    RaffleState private s_lotteryState;
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    /* Events */
    event RaffleEnter(address indexed player);
    event RaffledRequestId(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */
    constructor(
        address vrfCoordinator, // contract
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    )
        //uint256 lastTimeStamp
        VRFConsumerBaseV2(vrfCoordinator)
    {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = RaffleState.OPEN;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        // require (msg.value > i_entranceFee, "Not enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Raffle__notEnoughETHEntered();
        }
        if (s_lotteryState != RaffleState.OPEN) {
            revert Raffle_isNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
        // Emit an event when we update a dynamic array or mapping
        // Named events with the function name reversed
    }

    /**
     *  @dev This is the function that the Chainlink keeper nodes call
     * they look for the `upkeepNeeded` to return true
     * the following should be true in order to return true:
     * 1. Our time interval should have passed
     * 2. The lottery should atleast have 1 player, and have some ETH
     * 3. Our subscription is funded with LINK
     * 4. The lottery should be in an "OPEN" state.
     */

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (s_lotteryState == RaffleState.OPEN);
        bool hasTimePassed = (block.timestamp - s_lastTimeStamp > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);

        upkeepNeeded = (isOpen && hasTimePassed && hasPlayers && hasBalance);
    }

    function performUpkeep(
        bytes memory /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNeededFailed(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }
        s_lotteryState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // gasLane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        // this is redundant because the VRFCoordinatorMock RequestRandomWords also emits an event with the requestId
        emit RaffledRequestId(requestId);
    }

    function fulfillRandomWords(
        uint256, /*requestId*/
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_lotteryState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        // require(success)
        if (!success) {
            revert Raffle__TransferFail();
        }
        emit WinnerPicked(recentWinner);
    }

    /* View / Pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_lotteryState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
