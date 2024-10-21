// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle smart contract
 * @author Nkemjika
 * @notice This contract holds the logic for the raffle
 * @dev Implements chainlink VRF
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__NotEnoughEntranceFee();
    error Raffle_NotEnoughTime();
    error Raffle_TransferFailed();

    /* State variables */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval; // the duration of the lottery in seconds
    address payable[] private s_players;
    uint256 private s_lastTimeStamp; // the most recent b
    address private s_recentWinner; // the last winner

    bytes32 private immutable i_keyHash; // price willing to pay for the request
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit; // max amount of gas willing to spend
    uint32 private constant NUM_WORDS = 1;
    bool private constant ENABLE_NATIVE_PAYMENT = true;
    /* Events*/
    event RaffleEntered(address indexed player); // event emitted when a player enters the raffle

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        // s_vrfCoordinator.requestRandomWords();
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough entrace fee"); // Not gas efficient
        // require(msg.value >= i_entranceFee, NotEnoughEntranceFee()); // Newer but still not gas efficient

        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFee();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // Get random number
    // use random number to pick winner
    // be automatically called
    function pickWinner() external {
        // get current time
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle_NotEnoughTime();
        }

        // get random number from chainlink VRF
        // This happens in 2 steps/transactions
        // 1. request a random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: ENABLE_NATIVE_PAYMENT
                    })
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    // fullfill the request for random number
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    // Getter functions
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
