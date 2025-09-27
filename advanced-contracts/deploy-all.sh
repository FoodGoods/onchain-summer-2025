#!/bin/bash

# Advanced Contracts Master Deployment Script
# Deploys all 5 advanced smart contracts to Base Sepolia

set -e

echo "🚀 Starting Advanced Contracts Deployment to Base Sepolia"
echo "=================================================="

# Check if private key is set
if [ -z "$PRIVATE_KEY" ]; then
    echo "❌ Error: PRIVATE_KEY environment variable not set"
    echo "Please set your private key: export PRIVATE_KEY=your_private_key"
    exit 1
fi

# Check if RPC URL is set
if [ -z "$BASE_SEPOLIA_RPC_URL" ]; then
    echo "❌ Error: BASE_SEPOLIA_RPC_URL environment variable not set"
    echo "Please set the RPC URL: export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org"
    exit 1
fi

echo "✅ Environment variables configured"
echo "📍 Network: Base Sepolia"
echo "🔗 RPC URL: $BASE_SEPOLIA_RPC_URL"
echo ""

# Create deployment log file
DEPLOYMENT_LOG="deployment-$(date +%Y%m%d-%H%M%S).log"
echo "📝 Deployment log: $DEPLOYMENT_LOG"

# Function to deploy contract
deploy_contract() {
    local contract_name=$1
    local script_path=$2
    local contract_number=$3
    
    echo ""
    echo "🔄 Deploying Contract #$contract_number: $contract_name"
    echo "Script: $script_path"
    echo "----------------------------------------"
    
    if forge script "$script_path" --rpc-url "$BASE_SEPOLIA_RPC_URL" --broadcast --verify 2>&1 | tee -a "$DEPLOYMENT_LOG"; then
        echo "✅ Contract #$contract_number deployed successfully!"
        
        # Extract contract address from log
        CONTRACT_ADDRESS=$(grep "deployed at:" "$DEPLOYMENT_LOG" | tail -1 | sed 's/.*deployed at: //')
        echo "📍 Contract Address: $CONTRACT_ADDRESS"
        
        # Save to deployed contracts file
        echo "$contract_number,$contract_name,$CONTRACT_ADDRESS" >> deployed-contracts.csv
        
    else
        echo "❌ Contract #$contract_number deployment failed!"
        echo "Check the deployment log for details: $DEPLOYMENT_LOG"
        exit 1
    fi
}

# Initialize deployed contracts file
echo "Contract Number,Contract Name,Contract Address" > deployed-contracts.csv

# Deploy all contracts
deploy_contract "AdvancedMultiSigWallet" "contract-1-multisig/DeployMultiSig.s.sol" "1"
deploy_contract "AdvancedStakingToken" "contract-2-token-staking/DeployStakingToken.s.sol" "2"
deploy_contract "AdvancedNFTMarketplace" "contract-3-nft-marketplace/DeployNFTMarketplace.s.sol" "3"
deploy_contract "AdvancedYieldFarmingProtocol" "contract-4-defi-farming/DeployYieldFarming.s.sol" "4"
deploy_contract "AdvancedCrossChainBridge" "contract-5-cross-chain-bridge/DeployCrossChainBridge.s.sol" "5"

echo ""
echo "🎉 All 5 Advanced Contracts Deployed Successfully!"
echo "=================================================="
echo ""
echo "📊 Deployment Summary:"
echo "----------------------"
cat deployed-contracts.csv
echo ""
echo "📝 Full deployment log: $DEPLOYMENT_LOG"
echo "📋 Contract addresses: deployed-contracts.csv"
echo ""
echo "🔗 View contracts on Base Sepolia Explorer:"
echo "https://sepolia.basescan.org/"
echo ""
echo "🎯 Ready for Base Guild Application!"
echo "These contracts demonstrate advanced blockchain development skills."
