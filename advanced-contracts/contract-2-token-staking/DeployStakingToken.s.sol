// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../contract-2-token-staking/AdvancedStakingToken.sol";

contract DeployStakingToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        AdvancedStakingToken stakingToken = new AdvancedStakingToken();
        
        console.log("AdvancedStakingToken deployed at:", address(stakingToken));
        console.log("Total supply:", stakingToken.totalSupply());
        console.log("Token name:", stakingToken.name());
        console.log("Token symbol:", stakingToken.symbol());
        console.log("Number of staking pools:", stakingToken.getStakingPools().length);
        
        vm.stopBroadcast();
    }
}
