// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {HubRestricted} from "lens/HubRestricted.sol";
import {Types} from "lens/Types.sol";
import {LensModuleMetadata} from "lens/LensModuleMetadata.sol";
import {IPublicationActionModule} from "./interfaces/IPublicationActionModule.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ILensHub} from "./interfaces/ILensHub.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";

library BetTypes {
    /// @param creatorId: profile id of the bet creator
    /// @param userId: profile id of the challenged user
    /// @param jurorId: profile id of the juror
    /// @param currency: address of the token used for the bet
    /// @param amount: of required tokens to stake
    /// @param deadline: as unix timestamp
    /// @param staked: whether the creator has staked
    /// @param active: whether both parties have staked
    /// @param outcome: 0 for undecided, 1 for creator, 2 for user
    struct Bet {
        uint256 creatorId;
        uint256 userId;
        uint256 jurorId;
        address currency;
        uint256 amount;
        uint256 deadline;
        bool staked;
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

contract BetOpenAction is
    HubRestricted,
    IPublicationActionModule,
    LensModuleMetadata
{
    ILensHub public immutable LENS_HUB;
    IModuleRegistry public immutable MODULE_REGISTRY;

    mapping(uint256 profileId => mapping(uint256 pubId => BetTypes.Bet))
        public bets;

    error CurrencyNotWhitelisted();
    error DeadlineInPast();
    error InvalidJuror();
    error BetNotStaked();
    error BetAlreadyActive();
    error BetAlreadyFinalized();
    error BetExpired();
    error InvalidCaller();
    error BetNotActive();
    error BetNotExpired();
    error InvalidOutcome();

    event BetCreated(
        uint256 indexed pubId,
        uint256 indexed creatorId,
        uint256 indexed userId,
        uint256 jurorId,
        address currency,
        uint256 amount,
        uint256 deadline
    );

    event BetStaked(uint256 indexed pubId, uint256 indexed profileId);

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
        address moduleRegistryContract,
        address moduleOwner
    ) HubRestricted(lensHubProxyContract) LensModuleMetadata(moduleOwner) {
        LENS_HUB = ILensHub(lensHubProxyContract);
        MODULE_REGISTRY = IModuleRegistry(moduleRegistryContract);
    }

    function supportsInterface(
        bytes4 interfaceID
    ) public pure override returns (bool) {
        return
            interfaceID == type(IPublicationActionModule).interfaceId ||
            super.supportsInterface(interfaceID);
    }

    function initializePublicationAction(
        uint256 profileId,
        uint256 pubId,
        address,
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

        if (params.jurorId == params.userId || params.jurorId == profileId) {
            revert InvalidJuror();
        }

        bets[profileId][pubId] = BetTypes.Bet(
            profileId,
            params.userId,
            params.jurorId,
            params.currency,
            params.amount,
            params.deadline,
            false,
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

        if (!bet.staked) revert BetNotStaked();
        if (bet.active) revert BetAlreadyActive();
        if (bet.outcome != 0) revert BetAlreadyFinalized();
        if (bet.deadline < block.timestamp) revert BetExpired();
        if (bet.userId != params.actorProfileId) revert InvalidCaller();

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

    /// @notice creator stakes the bet amount
    /// @dev only callable by the bet creator
    function stake(uint256 pubId, uint256 profileId) external returns (bool) {
        BetTypes.Bet storage bet = bets[profileId][pubId];
        if (LENS_HUB.ownerOf(profileId) != msg.sender) revert InvalidCaller();
        if (bet.staked) revert BetAlreadyActive();

        bet.staked = true;

        IERC20(bet.currency).transferFrom(
            msg.sender,
            address(this),
            bet.amount
        );

        emit BetStaked(pubId, profileId);

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
        BetTypes.Bet storage bet = bets[profileId][pubId];
        if (!bet.active) revert BetNotActive();
        if (bet.outcome != 0) revert BetAlreadyFinalized();
        if (bet.deadline > block.timestamp) revert BetNotExpired();
        if (LENS_HUB.ownerOf(profileId) != msg.sender) revert InvalidCaller();
        if (outcome != 1 && outcome != 2) revert InvalidOutcome();

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
