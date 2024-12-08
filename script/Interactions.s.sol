// This contract is for programmatically creating and funcding a subscription
// we should create a subscription, fund the subscription and  add a consumer

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; //4
import {LinkToken} from "test/mocks/LinkToken.sol"; //16
import {Raffle} from "src/Raffle.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol"; //19

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        //2 & 7
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; // getConfig returns network config for active network
        address account = helperConfig.getConfig().account; //22
        (uint256 subId, ) = createSubscription(vrfCoordinator, account); //8
        return (subId, vrfCoordinator); //7
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        //3
        console.log("Creating subscription on chain Id: ", block.chainid);
        vm.startBroadcast(account); //5
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription(); // here vrfCoordinator is the address
        vm.stopBroadcast();

        console.log("Your subscription Id is: ", subId); //6
        console.log(
            "Please update the subscription Id in your HelperConfig.s.sol"
        );
        return (subId, vrfCoordinator);
    }

    function run() public {
        //1
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3 ether; //8   3 LINK
    uint256 public constant LOCAL_CHAIN_ID = 31337; //15

    //7
    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig(); //8
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId; //9
        address linkToken = helperConfig.getConfig().link; //10
        address account = helperConfig.getConfig().account; //23
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account); //11
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        //12
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            //14 if using anvil
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 100
            );
            vm.stopBroadcast();
        } else {
            //17 using sepolia
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        //13
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    //18
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account; //24
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, account); //20
    }

    function addConsumer(
        address contractToAddToVrf,
        address vrfCoordinator,
        uint256 subId,
        address account
    ) public {
        //19
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("To vrfCoordinator:", vrfCoordinator);
        console.log("On ChainId", block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subId,
            contractToAddToVrf
        );
        vm.stopBroadcast();
    }

    function run() external {
        //21
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
