// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    Raffle raffle;

    function deployRaffleContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subscriptionId == 0) {
            // create interactions in interactions files
            CreateSubscription createSubscriptionContract = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscriptionContract.createSubscription(config.vrfCoordinator);

            // fund subscription
            FundSubscription fundSubscriptionContract = new FundSubscription();
            fundSubscriptionContract.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.link);

            // add consumer
        }

        vm.startBroadcast();
        raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumerContract = new AddConsumer();
        addConsumerContract.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId);
        return (raffle, helperConfig);
    }

    function run() external returns (Raffle) {}
}
