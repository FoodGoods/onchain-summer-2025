// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contract-1-multisig/AdvancedMultiSigWallet.sol";

contract DeployMultiSig is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Create initial owners array
        address[] memory owners = new address[](3);
        owners[0] = msg.sender;
        owners[1] = 0x742d35Cc6634C0532925A3B8D4C9dB96C4B4d8B6; // Example address
        owners[2] = address(0x8ba1f109551bD432803012645ac136c22C131e); // Example address
        
        AdvancedMultiSigWallet multisig = new AdvancedMultiSigWallet(owners, 2);
        
        console.log("AdvancedMultiSigWallet deployed at:", address(multisig));
        console.log("Required confirmations:", multisig.required());
        console.log("Number of owners:", multisig.getOwners().length);
        
        vm.stopBroadcast();
    }
}
