// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol"; //1
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol"; //5 7 8

contract DeployRaffle is Script {
    function run() public {
        deployContract(); //9
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        //2
        HelperConfig helperConfig = new HelperConfig(); // A new helperConfig contract
        // local -> deploy mocks, get local config
        // sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); // This is network config

        if (config.subscriptionId == 0) {
            //4 if we don't have a subscriptionId we create a subscription
            CreateSubscription createSubscription = new CreateSubscription(); //6
            (config.subscriptionId, config.vrfCoordinator) = createSubscription
                .createSubscription(config.vrfCoordinator, config.account);

            // Then we Fund it
            FundSubscription fundSubscription = new FundSubscription(); //7
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        vm.startBroadcast(config.account); //3 parameters inside raffle
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer(); //8
        // don't need to broadcast
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );

        return (raffle, helperConfig);
    }
}
