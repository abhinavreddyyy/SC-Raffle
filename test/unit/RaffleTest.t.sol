// SPDX-License-Identfier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol"; // 23
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; //25
import {CodeConstants} from "script/HelperConfig.s.sol"; //31

contract RaffleTest is CodeConstants, Test {
    Raffle public raffle; //1
    HelperConfig public helperConfig; //2

    address public PLAYER = makeAddr("player"); //4 making address based on the string, this is for users to interact with raffle
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether; //5

    uint256 entranceFee; //6
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    event RaffleEntered(address indexed player); //14
    event WinnerPicked(address indexed winner);

    function setUp() external {
        //3
        DeployRaffle deployer = new DeployRaffle(); // new contract
        (raffle, helperConfig) = deployer.deployContract();
        // since deployContract returns a raffle and a helper config, we saved it to raffle and config variable by putting in above syntax
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); //7
        entranceFee = config.entranceFee; //8
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE); //12
    }

    function testRaffleInitializesInOpenState() public view {
        //9
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*              ENTER RAFFLE                     */

    function testRaffleRevertWhenYouDontPayEnough() public {
        //10    Arrange
        vm.prank(PLAYER);
        //Act/Assert
        //vm.expectRevert(); But to be more specific
        vm.expectRevert(Raffle.Raffle__SendMoreToEnterRaffle.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        //11 Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Asset
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
        // balance is zero for the PLAYER so give money
    }

    function testEnteringRaffleEmitsEvent() public {
        //13  Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle)); // means we're expecting to emit an event
        // as in the raffle it has only one index parameter so only one true and also there are no non-index parameters
        emit RaffleEntered(PLAYER); // this is the event that we're expecting to emit
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //15 Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // current_timestamp + interval(30secs) + 1, so making it always more than interval time
        vm.roll(block.number + 1); // time has changed and also one new block has been added
        raffle.performUpkeep("");

        //Act/Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*                 CHECKUPKEEP                  */

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // 16 Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleisntOpen() public {
        // 17 Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        //18  Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // 19 Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeepNeeded);
    }

    /*                  PERFORMUPKEEP               */

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //20 Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1); // updating the block time
        vm.roll(block.number + 1);

        //Act/assert
        raffle.performUpkeep(""); // It doesn't revert
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        //21 Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;

        //Act/assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                currentBalance,
                numPlayers,
                rState
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEntered() {
        //24
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _; // means modifier runs before our test runs
    }

    function testPerformUpkeepUpdateRaffleStateAndEmitsRequestId()
        public
        raffleEntered
        skipFork
    {
        //22 Act
        vm.recordLogs(); // records all emitted events inside an array
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs(); // all logs or events emitted in performUpkeep are sticked into entries array
        bytes32 requestId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*               FulfillrandomWords               */

    modifier skipFork() {
        //31
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEntered skipFork {
        // 26 Arrange/Act/assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector); // the InavlidRequest came from VRFCoordinatorV2_5Mock.sol file
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testfulfillrandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEntered
    {
        //27 Arrange
        uint256 additionalEntrants = 3; // 4 total, first player is already present through raffleEntered modifier
        uint256 startingIndex = 1;
        address expectedWinner = address(1); //29

        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance; //30

        //Act
        vm.recordLogs();
        raffle.performUpkeep(""); // this starts the chain link VRF
        Vm.Log[] memory entries = vm.getRecordedLogs(); // chainlink VRF going to create a bunch of logs
        bytes32 requestId = entries[1].topics[1]; // and get request id from logs
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //28 Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
