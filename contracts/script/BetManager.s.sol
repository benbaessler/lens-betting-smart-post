// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {IBetManager} from "src/interfaces/IBetManager.sol";
import {BetManager} from "src/BetManager.sol";
import {BetOpenAction} from "src/BetOpenAction.sol";

contract BetManagerScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address lensHubProxyAddress = 0x4fbffF20302F3326B20052ab9C217C44F6480900;
        IBetManager betManager = new BetManager(lensHubProxyAddress);

        new BetOpenAction(lensHubProxyAddress, address(betManager));

        vm.stopBroadcast();
    }
}
