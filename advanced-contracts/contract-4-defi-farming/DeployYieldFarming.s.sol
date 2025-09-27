// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contract-4-defi-farming/AdvancedYieldFarmingProtocol.sol";

contract DeployYieldFarming is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy a mock reward token first
        address rewardToken = address(0x1234567890123456789012345678901234567890); // Mock address
        
        AdvancedYieldFarmingProtocol farming = new AdvancedYieldFarmingProtocol(rewardToken);
        
        console.log("AdvancedYieldFarmingProtocol deployed at:", address(farming));
        console.log("Owner:", farming.owner());
        console.log("Reward token:", farming.rewardToken());
        console.log("Max APY:", farming.MAX_APY());
        
        vm.stopBroadcast();
    }
}
