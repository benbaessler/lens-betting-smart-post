// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {HubRestricted} from "lens/HubRestricted.sol";
import {Types} from "lens/Types.sol";
import {IPublicationActionModule} from "./interfaces/IPublicationActionModule.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ILensHub} from "./interfaces/ILensHub.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";

library BetTypes {
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
        bool active;
        uint256 outcome;
    }

    struct InitActionParams {
        uint256 userId;
        uint256 jurorId;
        address currency;
        uint256 amount;
        uint256 deadline;
    }
}

contract BetOpenAction is HubRestricted, IPublicationActionModule {
    ILensHub public immutable LENS_HUB;
    IModuleRegistry public immutable MODULE_REGISTRY;

    mapping(uint256 profileId => mapping(uint256 pubId => BetTypes.Bet))
        public bets;

    error CurrencyNotWhitelisted();
    error DeadlineInPast();

    event BetCreated(
        uint256 indexed pubId,
        uint256 indexed creatorId,
        uint256 indexed userId,
        uint256 jurorId,
        address currency,
        uint256 amount,
        uint256 deadline
    );

    // event Unstaked(
    //     uint256 indexed pubId,
    //     uint256 indexed profileId,
    //     uint256 indexed callerId
    // );

    event BetActivated(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 indexed challengedProfileId
    );

    event BetFinalized(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 outcome
    );

    constructor(
        address lensHubProxyContract,
        address moduleRegistryContract
    ) HubRestricted(lensHubProxyContract) {
        LENS_HUB = ILensHub(lensHubProxyContract);
        MODULE_REGISTRY = IModuleRegistry(moduleRegistryContract);
    }

    function initializePublicationAction(
        uint256 profileId,
        uint256 pubId,
        address transactionExecutor,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        BetTypes.InitActionParams memory params = abi.decode(
            data,
            (BetTypes.InitActionParams)
        );

        if (!MODULE_REGISTRY.isErc20CurrencyRegistered(params.currency)) {
            revert CurrencyNotWhitelisted();
        }

        if (block.timestamp > params.deadline) {
            revert DeadlineInPast();
        }

        IERC20(params.currency).transferFrom(
            transactionExecutor,
            address(this),
            params.amount
        );

        bets[profileId][pubId] = BetTypes.Bet(
            profileId,
            params.userId,
            params.jurorId,
            params.currency,
            params.amount,
            params.deadline,
            false,
            0
        );

        emit BetCreated(
            pubId,
            profileId,
            params.userId,
            params.jurorId,
            params.currency,
            params.amount,
            params.deadline
        );

        return data;
    }

    function processPublicationAction(
        Types.ProcessActionParams calldata params
    ) external override onlyHub returns (bytes memory) {
        BetTypes.Bet storage bet = bets[params.publicationActedProfileId][
            params.publicationActedId
        ];
        require(!bet.active, "Bet is already active");
        require(bet.outcome == 0, "Bet is already completed");
        require(
            bet.deadline > block.timestamp,
            "The deadline has already passed"
        );
        require(
            bet.userId == params.actorProfileId,
            "You are not allowed to stake for the challenged user"
        );

        IERC20(bet.currency).transferFrom(
            params.transactionExecutor,
            address(this),
            bet.amount
        );

        bet.active = true;

        emit BetActivated(
            params.publicationActedId,
            params.publicationActedProfileId,
            params.actorProfileId
        );

        return abi.encode(true);
    }

    /// @notice juror decides the outcome of the bet
    /// @dev only callable by the bet juror
    /// @param outcome: 1 for creator, 2 for user
    function finalize(
        uint256 pubId,
        uint256 profileId,
        uint256 outcome
    ) external {
        BetTypes.Bet storage bet = bets[profileId][pubId];
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
            IERC20(bet.currency).transfer(
                LENS_HUB.ownerOf(bet.creatorId),
                bet.amount * 2
            );
        } else if (outcome == 2) {
            IERC20(bet.currency).transfer(
                LENS_HUB.ownerOf(bet.userId),
                bet.amount * 2
            );
        }

        emit BetFinalized(pubId, profileId, outcome);
    }
}
