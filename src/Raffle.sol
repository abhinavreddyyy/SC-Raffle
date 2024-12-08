// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts

// Inside each contract, library or interface
// Type declarations
// State variables
// Events (prints things)
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol"; //18
import {VRFV2PlusClient} from "@chainlink/contracts/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol"; //18.1
import {console} from "forge-std/console.sol";

/**
 * @title  A Raffle contract
 * @author Abhinav
 * @notice This contract is used to create a raffle system where users can buy tickets and a winner is chosen randomly
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /** Errors */
    error Raffle__SendMoreToEnterRaffle(); //5
    error Raffle__TransferFailed(); //37
    error Raffle__RaffleNotOpen(); //41
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    ); //53

    /*Type Declarations*/
    enum RaffleState {
        OPEN,
        CALCULATING
    } //38

    /* state variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; //26
    uint32 private constant NUM_WORDS = 1; //29
    uint256 private immutable i_entranceFee; //2
    uint256 private immutable i_interval; //12 @dev duration of lottery in seconds
    bytes32 private immutable i_keyHash; //23
    uint256 private immutable i_subscriptionId; //24
    uint32 private immutable i_callbackGasLimit; //27
    address private immutable i_vrfCoordinator; //19
    address payable[] private s_players; //7 keeps changing so storage variable
    uint256 private s_lastTimeStamp; //15
    address private s_recentWinner; //32
    RaffleState private s_raffleState; //39

    // above is for list of players entering raffle

    /* Events*/
    event RaffleEntered(address indexed player); //9 defining event
    event WinnerPicked(address indexed winner); //47
    event RequestRaffleWinner(uint256 indexed requestId); //55 refactoring

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        // this contract is already present in VRFConsumerBaseV2Plus library
        //3 & 13 & vrf is 20 & 21
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = vrfCoordinator; //20
        i_keyHash = gasLane; //22
        i_subscriptionId = subscriptionId; //25
        i_callbackGasLimit = callbackGasLimit; //28

        s_lastTimeStamp = block.timestamp; //16
        s_raffleState = RaffleState.OPEN; //40
    }

    function enterRaffle() external payable {
        //1
        //require(msg.value >= i_enteranceFee, "Not enough ETH sent"); not gass efficient

        if (msg.value < i_entranceFee) {
            //6
            revert Raffle__SendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            //41
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender)); //8
        // This is for anytime someone enters the raffle
        emit RaffleEntered(msg.sender); //10
    }

    //1. Get a random number
    //2. Use the random number to pick a player

    // When should the winner be picked?
    /**
     * @dev This is the function that the chainlink nodes will call to see
     * if the lottery is ready to have a winner picked
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeeded true if it's time to restart the lottery
     * @return - ignored
     */

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        //42 @dev A function that checks if it's time for lottery to automatically be called and updated

        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval); // 43 1st point of above natspec
        bool isOpen = s_raffleState == RaffleState.OPEN; // 44 2nd point
        bool hasBalance = address(this).balance > 0; // 45 3rd point
        bool hasPlayers = s_players.length > 0; // 46
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers; // 47
        return (upkeepNeeded, ""); // 48
    }

    //3. Be automatically called when the raffle is over
    function performUpkeep(bytes calldata /* performData */) external {
        //49
        //11(pickWinner() external) now refactored to //49

        /* check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            //14 got refactored to performUpkeep
            revert();
        }
        */

        (bool upkeepNeeded, ) = checkUpkeep(""); //50
        if (!upkeepNeeded) {
            //51
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            ); //52
        }

        s_raffleState = RaffleState.CALCULATING; //42

        //17 All this is making request to chainlink VRF contract to get random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({ // VRFV2PlusClient contract has all the below ones in it
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            ) // new parameter
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request); // because of VRFConsumerBaseV2Plus having vrfcoordinator, we can call this function
        //30 request is made by calling vrfcoordinator and calling requestRandomWords and the above request struct

        emit RequestRaffleWinner(requestId); //56
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        //31
        // Checks

        // Effects (Internal Contract State Changes)
        uint256 /*requestId */,
        uint256[] calldata randomWords
    ) internal override {
        // this function process the response from the above request and selects the winner by using modulo operator
        uint256 indexOfWinner = randomWords[0] % s_players.length; //33
        address payable recentWinner = s_players[indexOfWinner]; //34
        s_recentWinner = recentWinner; //35

        s_raffleState = RaffleState.OPEN; //43 @dev raffle is open again
        s_players = new address payable[](0); //44 @dev deletes all the previous players and create a new empty array
        s_lastTimeStamp = block.timestamp; //45 @dev reset the timer, interval can restart
        emit WinnerPicked(s_recentWinner); //46 Basically shows everyone that it picked a winner

        // Interactions (External Contract Interactions)
        (bool success, ) = recentWinner.call{value: address(this).balance}(""); //36
        if (!success) {
            //37
            revert Raffle__TransferFailed();
        }
    }

    /** Getter Functions */

    function getEnteranceFee() external view returns (uint256) {
        //4
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        //53
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        //54
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        //57
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        //58
        return s_recentWinner;
    }
}
