// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contract-5-cross-chain-bridge/AdvancedCrossChainBridge.sol";

contract DeployCrossChainBridge is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        AdvancedCrossChainBridge bridge = new AdvancedCrossChainBridge();
        
        console.log("AdvancedCrossChainBridge deployed at:", address(bridge));
        console.log("Owner:", bridge.owner());
        console.log("Consensus threshold:", bridge.CONSENSUS_THRESHOLD());
        console.log("Number of validators:", bridge.getValidatorList().length);
        
        vm.stopBroadcast();
    }
}
