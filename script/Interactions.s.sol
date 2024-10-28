// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

// creating subscription from script and not UI

contract CreateSubscription is Script {
    function createSucbsciptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        (uint256 subId, ) = createSubscription(vrfCoordinator);

        return (subId, vrfCoordinator);
        // create s
    }

    function createSubscription(
        address vrfCoordinator
    ) public returns (uint256, address) {
        console2.log("creating subscription on chain id: ", block.chainid);

        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();

        vm.stopBroadcast();

        console2.log("Your subscription id is:", subId);
        console2.log("Please update the subscription in HelperConfig.s.sol");

        return (subId, vrfCoordinator);
    }

    function run() public {
        createSucbsciptionUsingConfig();
    }
}
