// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

/**
 * @title AdvancedCrossChainBridge
 * @dev Advanced cross-chain bridge with validator consensus and security mechanisms
 * @notice Implements asset bridging, validator management, and cross-chain message passing
 */
contract AdvancedCrossChainBridge {
    // Events
    event DepositInitiated(uint256 indexed depositId, address indexed user, address token, uint256 amount, uint256 targetChain);
    event DepositConfirmed(uint256 indexed depositId, bytes32 indexed txHash);
    event WithdrawalInitiated(uint256 indexed withdrawalId, address indexed user, address token, uint256 amount, uint256 sourceChain);
    event WithdrawalConfirmed(uint256 indexed withdrawalId, bytes32 indexed txHash);
    event ValidatorAdded(address indexed validator, uint256 weight);
    event ValidatorRemoved(address indexed validator);
    event ValidatorWeightUpdated(address indexed validator, uint256 newWeight);
    event ConsensusReached(uint256 indexed proposalId, bool approved);
    event SecurityAlert(uint256 indexed alertId, string reason, address indexed reporter);

    // Structs
    struct Deposit {
        address user;
        address token;
        uint256 amount;
        uint256 targetChain;
        uint256 timestamp;
        bool confirmed;
        bytes32 txHash;
        uint256 confirmations;
    }

    struct Withdrawal {
        address user;
        address token;
        uint256 amount;
        uint256 sourceChain;
        uint256 timestamp;
        bool confirmed;
        bytes32 txHash;
        uint256 confirmations;
    }

    struct Validator {
        address validator;
        uint256 weight;
        bool isActive;
        uint256 lastActivity;
        uint256 totalValidations;
    }

    struct ConsensusProposal {
        uint256 proposalType; // 0: deposit, 1: withdrawal, 2: validator change
        bytes data;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        mapping(address => bool) hasVoted;
    }

    struct SecurityAlertData {
        uint256 alertId;
        string reason;
        address reporter;
        uint256 timestamp;
        bool resolved;
        uint256 severity; // 1-5 scale
    }

    // State variables
    mapping(uint256 => Deposit) public deposits;
    mapping(uint256 => Withdrawal) public withdrawals;
    mapping(address => Validator) public validators;
    mapping(uint256 => ConsensusProposal) public consensusProposals;
    mapping(uint256 => SecurityAlertData) public securityAlerts;
    
    address[] public validatorList;
    uint256 public totalValidatorWeight;
    uint256 public constant MIN_VALIDATOR_WEIGHT = 100;
    uint256 public constant MAX_VALIDATOR_WEIGHT = 1000;
    uint256 public constant CONSENSUS_THRESHOLD = 66; // 66% consensus required
    uint256 public constant PROPOSAL_DURATION = 1 hours;
    uint256 public constant SECURITY_THRESHOLD = 3; // 3 alerts trigger pause
    
    uint256 public depositCounter;
    uint256 public withdrawalCounter;
    uint256 public proposalCounter;
    uint256 public alertCounter;
    
    address public owner;
    bool public bridgePaused;
    uint256 public totalVolumeBridged;
    uint256 public totalFeesCollected;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyValidator() {
        require(validators[msg.sender].isActive, "Not a validator");
        _;
    }

    modifier notPaused() {
        require(!bridgePaused, "Bridge is paused");
        _;
    }

    modifier validDeposit(uint256 depositId) {
        require(depositId < depositCounter, "Invalid deposit ID");
        require(!deposits[depositId].confirmed, "Deposit already confirmed");
        _;
    }

    modifier validWithdrawal(uint256 withdrawalId) {
        require(withdrawalId < withdrawalCounter, "Invalid withdrawal ID");
        require(!withdrawals[withdrawalId].confirmed, "Withdrawal already confirmed");
        _;
    }

    constructor() {
        owner = msg.sender;
        // Add owner as initial validator
        _addValidator(msg.sender, 1000);
    }

    // Deposit Functions
    function initiateDeposit(
        address token,
        uint256 amount,
        uint256 targetChain
    ) external notPaused returns (uint256 depositId) {
        require(amount > 0, "Amount must be positive");
        require(targetChain > 0, "Invalid target chain");

        depositId = depositCounter++;
        deposits[depositId] = Deposit({
            user: msg.sender,
            token: token,
            amount: amount,
            targetChain: targetChain,
            timestamp: block.timestamp,
            confirmed: false,
            txHash: bytes32(0),
            confirmations: 0
        });

        // Transfer tokens to bridge
        _transferToken(token, msg.sender, address(this), amount);

        emit DepositInitiated(depositId, msg.sender, token, amount, targetChain);
    }

    function confirmDeposit(uint256 depositId, bytes32 txHash) external onlyValidator validDeposit(depositId) {
        Deposit storage deposit = deposits[depositId];
        
        // Check if validator already confirmed
        require(!_hasValidatorConfirmed(depositId, msg.sender, true), "Already confirmed");

        deposit.confirmations++;
        validators[msg.sender].totalValidations++;
        validators[msg.sender].lastActivity = block.timestamp;

        // Check for consensus
        if (deposit.confirmations >= _getRequiredConfirmations()) {
            deposit.confirmed = true;
            deposit.txHash = txHash;
            totalVolumeBridged += deposit.amount;
            emit DepositConfirmed(depositId, txHash);
        }
    }

    // Withdrawal Functions
    function initiateWithdrawal(
        address token,
        uint256 amount,
        uint256 sourceChain,
        bytes32 sourceTxHash
    ) external onlyValidator notPaused returns (uint256 withdrawalId) {
        require(amount > 0, "Amount must be positive");
        require(sourceChain > 0, "Invalid source chain");
        require(sourceTxHash != bytes32(0), "Invalid source transaction");

        withdrawalId = withdrawalCounter++;
        withdrawals[withdrawalId] = Withdrawal({
            user: msg.sender, // In real implementation, this would be derived from source transaction
            token: token,
            amount: amount,
            sourceChain: sourceChain,
            timestamp: block.timestamp,
            confirmed: false,
            txHash: sourceTxHash,
            confirmations: 0
        });

        emit WithdrawalInitiated(withdrawalId, msg.sender, token, amount, sourceChain);
    }

    function confirmWithdrawal(uint256 withdrawalId) external onlyValidator validWithdrawal(withdrawalId) {
        Withdrawal storage withdrawal = withdrawals[withdrawalId];
        
        // Check if validator already confirmed
        require(!_hasValidatorConfirmed(withdrawalId, msg.sender, false), "Already confirmed");

        withdrawal.confirmations++;
        validators[msg.sender].totalValidations++;
        validators[msg.sender].lastActivity = block.timestamp;

        // Check for consensus
        if (withdrawal.confirmations >= _getRequiredConfirmations()) {
            withdrawal.confirmed = true;
            
            // Transfer tokens to user
            _transferToken(withdrawal.token, address(this), withdrawal.user, withdrawal.amount);
            
            emit WithdrawalConfirmed(withdrawalId, withdrawal.txHash);
        }
    }

    // Validator Management
    function addValidator(address validator, uint256 weight) external onlyOwner {
        require(weight >= MIN_VALIDATOR_WEIGHT && weight <= MAX_VALIDATOR_WEIGHT, "Invalid weight");
        require(!validators[validator].isActive, "Validator already exists");

        _addValidator(validator, weight);
    }

    function _addValidator(address validator, uint256 weight) internal {
        validators[validator] = Validator({
            validator: validator,
            weight: weight,
            isActive: true,
            lastActivity: block.timestamp,
            totalValidations: 0
        });
        
        validatorList.push(validator);
        totalValidatorWeight += weight;
        
        emit ValidatorAdded(validator, weight);
    }

    function removeValidator(address validator) external onlyOwner {
        require(validators[validator].isActive, "Validator not found");
        require(validatorList.length > 1, "Cannot remove last validator");

        validators[validator].isActive = false;
        totalValidatorWeight -= validators[validator].weight;

        // Remove from validator list
        for (uint256 i = 0; i < validatorList.length; i++) {
            if (validatorList[i] == validator) {
                validatorList[i] = validatorList[validatorList.length - 1];
                validatorList.pop();
                break;
            }
        }

        emit ValidatorRemoved(validator);
    }

    function updateValidatorWeight(address validator, uint256 newWeight) external onlyOwner {
        require(validators[validator].isActive, "Validator not found");
        require(newWeight >= MIN_VALIDATOR_WEIGHT && newWeight <= MAX_VALIDATOR_WEIGHT, "Invalid weight");

        uint256 oldWeight = validators[validator].weight;
        validators[validator].weight = newWeight;
        totalValidatorWeight = totalValidatorWeight - oldWeight + newWeight;

        emit ValidatorWeightUpdated(validator, newWeight);
    }

    // Consensus Mechanism
    function createConsensusProposal(uint256 proposalType, bytes memory data) external onlyValidator {
        uint256 proposalId = proposalCounter++;
        ConsensusProposal storage proposal = consensusProposals[proposalId];
        
        proposal.proposalType = proposalType;
        proposal.data = data;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + PROPOSAL_DURATION;
        proposal.executed = false;
    }

    function voteOnProposal(uint256 proposalId, bool support) external onlyValidator {
        ConsensusProposal storage proposal = consensusProposals[proposalId];
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!proposal.hasVoted[msg.sender], "Already voted");

        proposal.hasVoted[msg.sender] = true;
        uint256 weight = validators[msg.sender].weight;

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }
    }

    function executeProposal(uint256 proposalId) external onlyValidator {
        ConsensusProposal storage proposal = consensusProposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");

        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        uint256 consensusPercentage = (proposal.forVotes * 100) / totalVotes;

        require(consensusPercentage >= CONSENSUS_THRESHOLD, "Consensus not reached");

        proposal.executed = true;
        emit ConsensusReached(proposalId, true);

        // Execute proposal based on type
        _executeProposal(proposalId, proposal.proposalType, proposal.data);
    }

    function _executeProposal(uint256 proposalId, uint256 proposalType, bytes memory data) internal {
        // Implementation depends on proposal type
        // This is a simplified version
        console.log("Executing proposal %s of type %s", proposalId, proposalType);
    }

    // Security Features
    function reportSecurityAlert(string memory reason, uint256 severity) external onlyValidator {
        require(severity >= 1 && severity <= 5, "Invalid severity");
        
        uint256 alertId = alertCounter++;
        securityAlerts[alertId] = SecurityAlertData({
            alertId: alertId,
            reason: reason,
            reporter: msg.sender,
            timestamp: block.timestamp,
            resolved: false,
            severity: severity
        });

        emit SecurityAlert(alertId, reason, msg.sender);

        // Auto-pause bridge if too many high-severity alerts
        if (severity >= 4) {
            _checkSecurityThreshold();
        }
    }

    function _checkSecurityThreshold() internal {
        uint256 highSeverityAlerts = 0;
        for (uint256 i = 0; i < alertCounter; i++) {
            if (securityAlerts[i].severity >= 4 && !securityAlerts[i].resolved) {
                highSeverityAlerts++;
            }
        }

        if (highSeverityAlerts >= SECURITY_THRESHOLD) {
            bridgePaused = true;
        }
    }

    function resolveSecurityAlert(uint256 alertId) external onlyOwner {
        require(alertId < alertCounter, "Invalid alert ID");
        securityAlerts[alertId].resolved = true;
    }

    function unpauseBridge() external onlyOwner {
        bridgePaused = false;
    }

    // Internal Functions
    function _transferToken(address token, address from, address to, uint256 amount) internal {
        // Simplified - in real implementation, use actual ERC-20 transfer
        console.log("Transferring %s tokens from %s to %s", amount, from, to);
    }

    function _hasValidatorConfirmed(uint256 id, address validator, bool isDeposit) internal view returns (bool) {
        // Simplified - in real implementation, track individual confirmations
        return false;
    }

    function _getRequiredConfirmations() internal view returns (uint256) {
        // Require majority of validators
        return (validatorList.length / 2) + 1;
    }

    // View Functions
    function getDeposit(uint256 depositId) external view returns (Deposit memory) {
        return deposits[depositId];
    }

    function getWithdrawal(uint256 withdrawalId) external view returns (Withdrawal memory) {
        return withdrawals[withdrawalId];
    }

    function getValidator(address validator) external view returns (Validator memory) {
        return validators[validator];
    }

    function getValidatorList() external view returns (address[] memory) {
        return validatorList;
    }

    function getBridgeStats() external view returns (uint256, uint256, uint256, bool) {
        return (totalVolumeBridged, totalFeesCollected, validatorList.length, bridgePaused);
    }

    function getSecurityAlerts() external view returns (SecurityAlertData[] memory) {
        SecurityAlertData[] memory alerts = new SecurityAlertData[](alertCounter);
        for (uint256 i = 0; i < alertCounter; i++) {
            alerts[i] = securityAlerts[i];
        }
        return alerts;
    }

    // Emergency Functions
    function emergencyPause() external onlyOwner {
        bridgePaused = true;
    }

    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        _transferToken(token, address(this), owner, amount);
    }
}
