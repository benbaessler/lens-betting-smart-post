// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBetManager} from "./interfaces/IBetManager.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ILensHub} from "./interfaces/ILensHub.sol";

contract BetManager is IBetManager {
    /// @param creatorId: profile id of the bet creator
    /// @param userId: profile id of the challenged user
    /// @param amount: of required tokens to stake
    /// @param deadline: as unix timestamp
    /// @param juror: juror profile ids
    struct Bet {
        uint256 creatorId;
        uint256 userId;
        uint256 jurorId;
        uint256 amount;
        uint256 deadline;
        bool creatorStaked;
        bool userStaked;
        bool active;
        uint256 outcome;
    }

    ILensHub public lensHub =
        ILensHub(0xC1E77eE73403B8a7478884915aA599932A677870);

    mapping(uint256 profileId => mapping(uint256 pubId => Bet)) public bets;

    function createBet(
        uint256 pubId,
        uint256 creatorId,
        uint256 userId,
        uint256 jurorId,
        uint256 amount,
        uint256 deadline
    ) external {
        require(amount > 0, "Amount can not be zero");
        require(
            deadline > block.timestamp,
            "The deadline can not be in the past"
        );

        bets[creatorId][pubId] = Bet(
            creatorId,
            userId,
            jurorId,
            amount,
            deadline,
            false,
            false,
            false,
            0
        );
    }

    /// @notice participants stake tokens to activate the bet
    /// @param stakerId: profile id of the staker
    function stake(
        uint256 pubId,
        uint256 profileId,
        uint256 stakerId
    ) external payable returns (bool) {
        Bet storage bet = bets[profileId][pubId];
        require(
            bet.creatorId == stakerId || bet.userId == stakerId,
            "You are not allowed to stake for this bet"
        );
        require(!bet.active, "Bet is already active");
        require(bet.outcome == 0, "Bet is already completed");
        require(
            bet.deadline > block.timestamp,
            "The deadline has already passed"
        );
        require(msg.value == bet.amount, "Incorrect amount");

        if (bet.creatorId == stakerId) {
            require(
                lensHub.ownerOf(bet.creatorId) == msg.sender,
                "You are not allowed to stake for the creator"
            );
            require(!bet.creatorStaked, "Creator already staked");
            bet.creatorStaked = true;
        } else if (bet.userId == stakerId) {
            require(
                lensHub.ownerOf(bet.userId) == msg.sender,
                "You are not allowed to stake for the challenged user"
            );
            require(!bet.userStaked, "User already staked");
            bet.userStaked = true;
        }

        if (bet.creatorStaked && bet.userStaked) {
            bet.active = true;
        }

        return true;
    }

    /// @notice participants withdraw their stake
    /// @param stakerId: profile id of the staker
    function unstake(
        uint256 pubId,
        uint256 profileId,
        uint256 stakerId
    ) external returns (bool) {
        Bet storage bet = bets[profileId][pubId];
        require(
            bet.creatorId == stakerId || bet.userId == stakerId,
            "You are not allowed to unstake for this bet"
        );
        require(!bet.active, "Bet is already active");
        require(bet.outcome == 0, "Bet is already completed");

        if (bet.creatorId == stakerId) {
            require(
                lensHub.ownerOf(bet.creatorId) == msg.sender,
                "You are not allowed to unstake for the creator"
            );
            require(bet.creatorStaked, "Creator did not stake");
            bet.creatorStaked = false;
        } else if (bet.userId == stakerId) {
            require(
                lensHub.ownerOf(bet.userId) == msg.sender,
                "You are not allowed to unstake for the challenged user"
            );
            require(bet.userStaked, "User did not stake");
            bet.userStaked = false;
        }

        payable(msg.sender).transfer(bet.amount);

        return true;
    }

    /// @notice juror decides the outcome of the bet
    /// @dev only callable by the bet juror
    /// @param outcome: 1 for creator, 2 for user
    function finalize(
        uint256 pubId,
        uint256 profileId,
        uint256 outcome
    ) external {
        Bet storage bet = bets[profileId][pubId];
        require(bet.active, "Bet is not active");
        require(bet.outcome == 0, "Bet is already completed");
        require(
            bet.deadline < block.timestamp,
            "The deadline has not yet passed"
        );
        require(
            lensHub.ownerOf(bet.jurorId) == msg.sender,
            "You are not allowed to decide for this bet"
        );
        require(outcome == 1 || outcome == 2, "Invalid outcome");

        bet.outcome = outcome;

        if (outcome == 1) {
            payable(lensHub.ownerOf(bet.creatorId)).transfer(bet.amount * 2);
        } else if (outcome == 2) {
            payable(lensHub.ownerOf(bet.userId)).transfer(bet.amount * 2);
        }
    }
}
