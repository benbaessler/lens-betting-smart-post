// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {ILensHub} from "./interfaces/ILensHub.sol";

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

    ILensHub public lensHub =
        ILensHub(0xC1E77eE73403B8a7478884915aA599932A677870);

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

    /// @notice participants stake tokens to activate the bet
    /// @param staker: 0 for creator, 1 for challenged user
    function stake(
        uint256 pubId,
        uint256 profileId,
        uint256 staker
    ) external payable {
        require(
            staker < 3,
            "Invalid staker value: must be 0 for creator or 1 for challenged user"
        );

        Bet storage bet = bets[profileId][pubId];
        require(!bet.active, "Bet is already active");
        require(!bet.decided, "Bet is already completed");
        require(
            bet.deadline > block.timestamp,
            "The deadline has already passed"
        );
        require(msg.value == bet.amount, "Incorrect amount");

        if (staker == 0) {
            require(
                lensHub.ownerOf(bet.creatorId) == msg.sender,
                "You are not allowed to stake for the creator"
            );
            bet.creatorStaked = true;
        } else if (staker == 1) {
            require(
                lensHub.ownerOf(bet.userId) == msg.sender,
                "You are not allowed to stake for the challenged user"
            );
            bet.userStaked = true;
        }

        if (bet.creatorStaked && bet.userStaked) {
            bet.active = true;
        }
    }
}
