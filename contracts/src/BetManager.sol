// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBetManager} from "./interfaces/IBetManager.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ILensHub} from "./interfaces/ILensHub.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";

library Types {
    /// @param creatorId: profile id of the bet creator
    /// @param userId: profile id of the challenged user
    /// @param amount: of required tokens to stake
    /// @param deadline: as unix timestamp
    /// @param juror: juror profile ids
    struct Bet {
        uint256 creatorId;
        uint256 userId;
        uint256 jurorId;
        address currency;
        uint256 amount;
        uint256 deadline;
        bool creatorStaked;
        bool userStaked;
        bool active;
        uint256 outcome;
    }
}

contract BetManager {
    mapping(uint256 profileId => mapping(uint256 pubId => Types.Bet)) public bets;

    ILensHub public immutable LENS_HUB;
    IModuleRegistry public immutable MODULE_REGISTRY;

    event BetCreated(
        uint256 indexed pubId,
        uint256 indexed creatorId,
        uint256 indexed userId,
        uint256 jurorId,
        uint256 amount,
        uint256 deadline
    );

    event CreatorStaked(uint256 indexed pubId, uint256 indexed profileId);

    event UserStaked(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 indexed stakerId
    );

    event Unstaked(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 indexed callerId
    );

    event BetActivated(uint256 indexed pubId, uint256 indexed profileId);

    event BetFinalized(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 outcome
    );

    constructor(address lensHubProxyContract, address moduleRegistryContract) {
        LENS_HUB = ILensHub(lensHubProxyContract);
        MODULE_REGISTRY = IModuleRegistry(moduleRegistryContract);
    }

    // TODO: Remove require statements; if/revert with custom errors

    function createBet(
        uint256 pubId,
        uint256 creatorId,
        uint256 userId,
        uint256 jurorId,
        address currency,
        uint256 amount,
        uint256 deadline
    ) external {
        require(amount > 0, "Amount can not be zero");
        require(
            deadline > block.timestamp,
            "The deadline can not be in the past"
        );

        bets[creatorId][pubId] = Types.Bet(
            creatorId,
            userId,
            jurorId,
            currency,
            amount,
            deadline,
            false,
            false,
            false,
            0
        );

        emit BetCreated(pubId, creatorId, userId, jurorId, amount, deadline);
    }

    /// @notice participants stake tokens to activate the bet
    /// @param stakerId: profile id of the staker
    function stake(
        uint256 pubId,
        uint256 profileId,
        uint256 stakerId
    ) external returns (bool) {
        Types.Bet storage bet = bets[profileId][pubId];
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
        // require(msg.value == bet.amount, "Incorrect amount");

        if (bet.creatorId == stakerId) {
            require(
                LENS_HUB.ownerOf(bet.creatorId) == msg.sender,
                "You are not allowed to stake for the creator"
            );
            require(!bet.creatorStaked, "Creator already staked");
            bet.creatorStaked = true;

            emit CreatorStaked(pubId, profileId);
        } else if (bet.userId == stakerId) {
            require(
                LENS_HUB.ownerOf(bet.userId) == msg.sender,
                "You are not allowed to stake for the challenged user"
            );
            require(!bet.userStaked, "User already staked");
            bet.userStaked = true;

            emit UserStaked(pubId, profileId, stakerId);
        }

        if (bet.creatorStaked && bet.userStaked) {
            bet.active = true;
            emit BetActivated(pubId, profileId);
        }

        return true;
    }

    /// @notice participants withdraw their stake
    /// @param callerId: profile id of the staker
    function unstake(
        uint256 pubId,
        uint256 profileId,
        uint256 callerId
    ) external returns (bool) {
        Types.Bet storage bet = bets[profileId][pubId];
        require(
            bet.creatorId == callerId || bet.userId == callerId,
            "You are not allowed to unstake for this bet"
        );
        require(!bet.active, "Bet is already active");
        require(bet.outcome == 0, "Bet is already completed");

        if (bet.creatorId == callerId) {
            require(
                LENS_HUB.ownerOf(bet.creatorId) == msg.sender,
                "You are not allowed to unstake for the creator"
            );
            require(bet.creatorStaked, "Creator did not stake");
            bet.creatorStaked = false;
        } else if (bet.userId == callerId) {
            require(
                LENS_HUB.ownerOf(bet.userId) == msg.sender,
                "You are not allowed to unstake for the challenged user"
            );
            require(bet.userStaked, "User did not stake");
            bet.userStaked = false;
        }

        payable(msg.sender).transfer(bet.amount);

        emit Unstaked(pubId, profileId, callerId);

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
        Types.Bet storage bet = bets[profileId][pubId];
        require(bet.active, "Bet is not active");
        require(bet.outcome == 0, "Bet is already completed");
        require(
            bet.deadline <= block.timestamp,
            "The deadline has not yet passed"
        );
        require(
            LENS_HUB.ownerOf(bet.jurorId) == msg.sender,
            "You are not allowed to decide for this bet"
        );
        require(outcome == 1 || outcome == 2, "Invalid outcome");

        bet.outcome = outcome;

        if (outcome == 1) {
            payable(LENS_HUB.ownerOf(bet.creatorId)).transfer(bet.amount * 2);
        } else if (outcome == 2) {
            payable(LENS_HUB.ownerOf(bet.userId)).transfer(bet.amount * 2);
        }

        emit BetFinalized(pubId, profileId, outcome);
    }
}
