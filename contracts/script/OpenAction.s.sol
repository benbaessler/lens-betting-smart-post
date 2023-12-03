// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {BetOpenAction} from "src/BetOpenAction.sol";

contract OpenActionScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address lensHubProxyAddress = 0x4fbffF20302F3326B20052ab9C217C44F6480900;
        address moduleRegistryAddress = 0x4BeB63842BB800A1Da77a62F2c74dE3CA39AF7C0;

        new BetOpenAction(lensHubProxyAddress, moduleRegistryAddress);

        vm.stopBroadcast();
    }
}
