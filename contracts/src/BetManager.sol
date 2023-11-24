// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BetManager {

    /// @param userOne: profile id of user 1
    /// @param userTwo: profile id of user 2
    /// @param token: used token address
    /// @param amount: of required tokens to stake
    /// @param deadline: as unix timestamp
    /// @param jurors: array of jurors' profile ids
    struct Bet {
        uint256 userOne;
        uint256 userTwo;
        address token;
        uint256 amount;
        uint256 deadline;
        uint256[] jurors;
        bool active;
        bool decided;
        bool outcome;
    }
}