// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/OnchainSummer2025.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        OnchainSummer2025 deployedContract = new OnchainSummer2025("Hello Base Guild!");
        
        console.log("Contract deployed at:", address(deployedContract));
        console.log("Contract owner:", deployedContract.owner());
        console.log("Initial message:", deployedContract.message());
        
        vm.stopBroadcast();
    }
}
