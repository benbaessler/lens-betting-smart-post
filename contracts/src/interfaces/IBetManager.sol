// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ILensHub} from "./ILensHub.sol";

interface IBetManager {
    function bets(
        uint256 profileId,
        uint256 pubId
    )
        external
        view
        returns (
            uint256 creatorId,
            uint256 userId,
            uint256 jurorId,
            uint256 amount,
            uint256 deadline,
            bool creatorStaked,
            bool userStaked,
            bool active,
            uint256 outcome
        );

    function createBet(
        uint256 pubId,
        uint256 creatorId,
        uint256 userId,
        uint256 jurorId,
        uint256 amount,
        uint256 deadline
    ) external;

    function finalize(
        uint256 pubId,
        uint256 profileId,
        uint256 outcome
    ) external;

    function stake(
        uint256 pubId,
        uint256 profileId,
        uint256 stakerId
    ) external returns (bool);

    function unstake(
        uint256 pubId,
        uint256 profileId,
        uint256 stakerId
    ) external returns (bool);
}
