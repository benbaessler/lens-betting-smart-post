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
        bool creatorStaked;
        bool accepted;
        bool userStaked;
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
    error ActionAlreadyExecuted();
    error NotStaked();
    error BetAlreadyActive();
    error BetAlreadyFinalized();
    error BetExpired();
    error InvalidCaller();
    error BetNotActive();
    error BetNotExpired();
    error BetNotAccepted();
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

    event BetStaked(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 indexed stakerId
    );

    event Unstaked(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 indexed callerId
    );

    event BetAccepted(
        uint256 indexed pubId,
        uint256 indexed profileId,
        uint256 indexed challengedProfileId
    );

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

        if (bet.accepted) revert ActionAlreadyExecuted();
        if (bet.deadline < block.timestamp) revert BetExpired();
        if (bet.userId != params.actorProfileId) revert InvalidCaller();

        bet.accepted = true;

        emit BetAccepted(
            params.publicationActedId,
            params.publicationActedProfileId,
            params.actorProfileId
        );

        return abi.encode(true);
    }

    /// @notice staker stakes on the bet
    /// @dev only callable by the bet creator or challenged user
    function stake(
        uint256 pubId,
        uint256 profileId,
        uint256 stakerId
    ) external returns (bool) {
        BetTypes.Bet storage bet = bets[profileId][pubId];

        address creatorAddress = LENS_HUB.ownerOf(profileId);
        address userAddress = LENS_HUB.ownerOf(bet.userId);
        if (creatorAddress != msg.sender && userAddress != msg.sender)
            revert InvalidCaller();

        IERC20(bet.currency).transferFrom(
            msg.sender,
            address(this),
            bet.amount
        );

        if (creatorAddress == msg.sender) {
            if (bet.creatorStaked) revert ActionAlreadyExecuted();
            bet.creatorStaked = true;
        } else {
            if (bet.userStaked) revert ActionAlreadyExecuted();
            if (!bet.accepted) revert BetNotAccepted();
            bet.userStaked = true;
        }

        emit BetStaked(pubId, profileId, stakerId);

        return true;
    }

    /// @notice staker unstakes from the bet
    /// @dev only callable by the bet creator or challenged user
    function unstake(
        uint256 pubId,
        uint256 profileId,
        uint256 callerId
    ) external returns (bool) {
        BetTypes.Bet storage bet = bets[profileId][pubId];

        address creatorAddress = LENS_HUB.ownerOf(profileId);
        address userAddress = LENS_HUB.ownerOf(bet.userId);

        if (creatorAddress != msg.sender && userAddress != msg.sender)
            revert InvalidCaller();
        if (bet.active) revert BetAlreadyActive();

        if (creatorAddress == msg.sender) {
            if (!bet.creatorStaked) revert NotStaked();
            bet.creatorStaked = false;
        } else {
            if (!bet.userStaked) revert NotStaked();
            bet.userStaked = false;
        }

        IERC20(bet.currency).transfer(msg.sender, bet.amount);

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
