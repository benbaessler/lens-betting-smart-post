// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {HubRestricted} from "lens/HubRestricted.sol";
import {Types} from "lens/Types.sol";
import {IPublicationActionModule} from "./interfaces/IPublicationActionModule.sol";
import {IBetManager} from "./interfaces/IBetManager.sol";

contract BetOpenAction is HubRestricted, IPublicationActionModule {
    IBetManager public betManager;

    constructor(
        address lensHubProxyContract,
        address betManagerContract
    ) HubRestricted(lensHubProxyContract) {
        betManager = IBetManager(betManagerContract);
    }

    function initializePublicationAction(
        uint256 profileId,
        uint256 pubId,
        address /* transactionExecutor */,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        (
            uint256 userId,
            uint256 jurorId,
            uint256 amount,
            uint256 deadline
        ) = abi.decode(data, (uint256, uint256, uint256, uint256));

        betManager.createBet({
            pubId: pubId,
            creatorId: profileId,
            userId: userId,
            jurorId: jurorId,
            amount: amount,
            deadline: deadline
        });

        return data;
    }

    function processPublicationAction(
        Types.ProcessActionParams calldata params
    ) external override onlyHub returns (bytes memory) {
        bool success = betManager.stake(
            params.publicationActedId,
            params.publicationActedProfileId,
            params.actorProfileId
        );

        return abi.encode(success);
    }
}
