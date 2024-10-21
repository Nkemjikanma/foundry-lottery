// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title Raffle smart contract
 * @author Nkemjika
 * @notice This contract holds the logic for the raffle
 * @dev Implements chainlink VRF
 */
contract Raffle {
    /**
     * Errors
     */
    error Raffle__NotEnoughEntranceFee();

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events*/
    event RaffleEntered(address indexed player); // event emitted when a player enters the raffle

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough entrace fee"); // Not gas efficient
        // require(msg.value >= i_entranceFee, NotEnoughEntranceFee()); // Newer but still not gas efficient

        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntranceFee();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() public {}

    // Getter functions
    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
