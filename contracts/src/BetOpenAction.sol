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
    /// @param userId: profile id of the challenged user
    /// @param judgeId: profile id of the judge
    /// @param currency: address of the token used for the bet
    /// @param amount: of required tokens to stake
    /// @param deadline: as unix timestamp
    /// @param active: if both parties have staked
    /// @param outcome: 0 for undecided, 1 for creator, 2 for user
    struct Bet {
        uint256 userId;
        uint256 judgeId;
        address currency;
        uint256 amount;
        uint256 deadline;
        bool active;
        uint256 outcome;
    }

    struct InitActionParams {
        uint256 userId;
        uint256 judgeId;
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
    error ActionAlreadyExecuted();
    error InvalidVote();
    error NotStaked();
    error InvalidCaller();
    error InvalidDeadline();
    error InvalidJudge();
    error InvalidOutcome();
    error BetAlreadyActive();
    error BetExpired();
    error BetNotActive();
    error BetNotExpired();

    event BetCreated(
        uint256 indexed pubId,
        uint256 indexed creatorId,
        uint256 indexed userId,
        uint256 judgeId,
        address currency,
        uint256 amount,
        uint256 deadline
    );

    event Unstaked(uint256 indexed pubId, uint256 indexed profileId);

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
            revert InvalidDeadline();
        }

        if (params.judgeId == profileId || params.judgeId == params.userId) {
            revert InvalidJudge();
        }

        IERC20(params.currency).transferFrom(
            transactionExecutor,
            address(this),
            params.amount
        );

        bets[profileId][pubId] = BetTypes.Bet(
            params.userId,
            params.judgeId,
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
            params.judgeId,
            params.currency,
            params.amount,
            params.deadline
        );

        return new bytes(0);
    }

    function processPublicationAction(
        Types.ProcessActionParams calldata params
    ) external override onlyHub returns (bytes memory) {
        BetTypes.Bet storage bet = bets[params.publicationActedProfileId][
            params.publicationActedId
        ];

        if (bet.active) revert ActionAlreadyExecuted();
        if (block.timestamp > bet.deadline) revert BetExpired();
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

        return new bytes(0);
    }

    /// @notice staker unstakes from the bet
    /// @dev only callable by the bet creator or challenged user
    // function unstake(
    //     uint256 pubId,
    //     uint256 profileId,
    //     uint256 callerId
    // ) external returns (bool) {
    //     BetTypes.Bet storage bet = bets[profileId][pubId];

    //     address creatorAddress = LENS_HUB.ownerOf(profileId);
    //     address userAddress = LENS_HUB.ownerOf(bet.userId);

    //     if (creatorAddress != msg.sender && userAddress != msg.sender)
    //         revert InvalidCaller();
    //     if (bet.active) revert BetAlreadyActive();

    //     if (creatorAddress == msg.sender) {
    //         if (!bet.creatorStaked) revert NotStaked();
    //         bet.creatorStaked = false;
    //     } else {
    //         if (!bet.userStaked) revert NotStaked();
    //         bet.userStaked = false;
    //     }

    //     IERC20(bet.currency).transfer(msg.sender, bet.amount);

    //     emit Unstaked(pubId, profileId, callerId);

    //     return true;
    // }

    /// @notice judge finalizes the bet by deciding the outcome
    /// @dev only callable by the bet's judge
    /// @param outcome: 1 for creator, 2 for user
    function finalize(
        uint256 pubId,
        uint256 profileId,
        uint256 outcome
    ) external {
        BetTypes.Bet storage bet = bets[profileId][pubId];

        if (!bet.active) revert BetNotActive();
        if (bet.outcome != 0) revert ActionAlreadyExecuted();
        if (bet.deadline > block.timestamp) revert BetNotExpired();
        if (LENS_HUB.ownerOf(bet.judgeId) != msg.sender) revert InvalidCaller();
        if (outcome != 1 && outcome != 2) revert InvalidOutcome();

        bet.outcome = outcome;

        if (outcome == 1) {
            IERC20(bet.currency).transfer(
                LENS_HUB.ownerOf(profileId),
                bet.amount * 2
            );
        } else {
            IERC20(bet.currency).transfer(
                LENS_HUB.ownerOf(bet.userId),
                bet.amount * 2
            );
        }

        emit BetFinalized(pubId, profileId, bet.outcome);
    }

    // Getters

    function getBet(
        uint256 pubId,
        uint256 profileId
    ) external view returns (BetTypes.Bet memory) {
        return bets[profileId][pubId];
    }
}
