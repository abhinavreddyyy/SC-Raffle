// Most of helper config code is from past examples, chatgpt etc

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "lib/forge-std/src/Script.sol";
//import {VRFCoordinatorV2_5Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; //13
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol"; //13
import {LinkToken} from "test/mocks/LinkToken.sol"; //23

abstract contract CodeConstants {
    /* VRF Mock Values*/
    uint96 public MOCK_BASE_FEE = 0.25 ether; //15
    uint96 public MOCK_GAS_PRICE_LINK = 1e9; //16
    // LINK/ETH Price
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15; //17

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111; //6
    uint256 public constant LOCAL_CHAIN_ID = 31337; //9
}

contract HelperConfig is CodeConstants, Script {
    // & 1
    error HelperConfig__InvalidChainId(); //11

    struct NetworkConfig {
        //2
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link; //21
        address account; //27
    }

    NetworkConfig public localNetworkConfig; //3
    mapping(uint256 chainId => NetworkConfig) public networkConfigs; //4

    constructor() {
        //7
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    // Function to fetch the appropriate config based on actual chain ID
    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        //8
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            // meaning if the vrfcoordinator is not empty, we're verifying that VRF corrdinator exists
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            //10
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        //20
        return getConfigByChainId(block.chainid);
    }

    /* Network specific config
        1. Sepolia
        2. local network
    */

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        //5 this is testnet
        return
            NetworkConfig({
                entranceFee: 0.01 ether, // 1000000000000000 1e16
                interval: 30, // 30 seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // from  chainlink docs
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // same
                callbackGasLimit: 500000, // 5,00,000 gas
                subscriptionId: 0,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, //22
                account: 0xb12e7c0760eC517cB40E72d75d71714c14867754 // 27 address of my metamask private key
            });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        //12 this is localnet and also check to see if we set an active network config
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        // if the above is false  we need to deploy mocks

        vm.startBroadcast(); //14
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE, // flat fee that VRF charges for provided randomness
            MOCK_GAS_PRICE_LINK, // gas consumed by VRF node when calling your function
            MOCK_WEI_PER_UINT_LINK // LINK price in ETH in wei units
        ); //18
        LinkToken linkToken = new LinkToken(); //24
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({ //19
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // same
            callbackGasLimit: 500000,
            subscriptionId: 0,
            link: address(linkToken), //25
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38 //27 got from default address present in base.sol
        });
        return localNetworkConfig;
    }
}
