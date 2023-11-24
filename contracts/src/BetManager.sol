// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";

contract BetManager {
    /// @param creatorId: profile id of the bet creator
    /// @param userId: profile id of the challenged user
    /// @param amount: of required tokens to stake
    /// @param deadline: as unix timestamp
    /// @param jurors: array of jurors' profile ids
    struct Bet {
        uint256 creatorId;
        uint256 userId;
        uint256 amount;
        uint256 deadline;
        uint256[] jurors;
        bool creatorStaked;
        bool userStaked;
        bool active;
        bool decided;
        bool outcome;
    }

    mapping(uint256 profileId => mapping(uint256 pubId => Bet)) private bets;

    function createBet(
        uint256 pubId,
        uint256 creatorId,
        uint256 userId,
        uint256 amount,
        uint256 deadline,
        uint256[] memory jurors
    ) external {
        require(jurors.length > 0, "There must be at least 1 juror");
        require(amount > 0, "Amount can not be zero");
        require(
            deadline > block.timestamp,
            "The deadline can not be in the past"
        );

        bets[creatorId][pubId] = Bet(
            creatorId,
            userId,
            amount,
            deadline,
            jurors,
            false,
            false,
            false,
            false,
            false
        );
    }
}
