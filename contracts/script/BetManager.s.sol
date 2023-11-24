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

        IBetManager betManager = new BetManager();
        address lensHubProxyAddress = 0xC1E77eE73403B8a7478884915aA599932A677870;

        new BetOpenAction(lensHubProxyAddress, address(betManager));

        vm.stopBroadcast();
    }
}
