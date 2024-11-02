// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

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
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 players, uint256 raffleState);
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

    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    // Enums can be used to create custom types with a finite set of constant values

    RaffleState private s_raffleState;

    /* Events*/
    event RaffleEntered(address indexed player); // event emitted when a player enters the raffle
    event WinnerPicked(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

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
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough entrace fee"); // Not gas efficient
        // require(msg.value >= i_entranceFee, NotEnoughEntranceFee()); // Newer but still not gas efficient
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFee();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    // Get random number
    // use random number to pick winner
    // be automatically called
    function pickWinner() internal {
        // get current time
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert Raffle_NotEnoughTime();
        }

        s_raffleState = RaffleState.CALCULATING;

        // get random number from chainlink VRF
        // This happens in 2 steps/transactions
        // 1. request a random number
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: ENABLE_NATIVE_PAYMENT}))
        });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        //
        emit RequestedRaffleWinner(requestId);
    }

    // fullfill the request for random number
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN; // open raffle state

        s_players = new address payable[](0); // reset list of players
        s_lastTimeStamp = block.timestamp; // change the time to current block time

        emit WinnerPicked(s_recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_TransferFailed();
        }
    }

    // /**
    //  * @dev This is the function that chainlink nodes call to see if the lottery is ready to have a winner picked.
    //  * The following need to be true for upkeepNeeded to be true:
    //  * 1. The time interval has passed between interval runs.
    //  * 2. The lottery is open
    //  * 3. The contract has ETH
    //  * 4. Our subscription has LINK
    //  * @param
    //  * @return upkeepNeeded
    //  * @return
    //  */
    function checkUpKeep(bytes memory /* callData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upkeepNeeded, hex"");
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upKeepNeeded,) = checkUpKeep("");

        if (!upKeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        pickWinner();
    }

    // Getter functions
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
