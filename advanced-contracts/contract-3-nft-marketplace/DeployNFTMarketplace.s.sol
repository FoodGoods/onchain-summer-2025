// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contract-3-nft-marketplace/AdvancedNFTMarketplace.sol";

contract DeployNFTMarketplace is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        AdvancedNFTMarketplace marketplace = new AdvancedNFTMarketplace();
        
        console.log("AdvancedNFTMarketplace deployed at:", address(marketplace));
        console.log("Owner:", marketplace.owner());
        console.log("Platform fee rate:", marketplace.PLATFORM_FEE_RATE());
        
        vm.stopBroadcast();
    }
}
