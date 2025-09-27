// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

/**
 * @title AdvancedStakingToken
 * @dev ERC-20 token with advanced staking, yield farming, and governance features
 * @notice Implements multiple staking pools, compound rewards, and governance voting
 */
contract AdvancedStakingToken {
    // Events
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint256 poolId, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 poolId, uint256 amount, uint256 rewards);
    event RewardsClaimed(address indexed user, uint256 poolId, uint256 amount);
    event PoolCreated(uint256 indexed poolId, uint256 apy, uint256 lockDuration);
    event GovernanceProposalCreated(uint256 indexed proposalId, string description);
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool support, uint256 votes);
    event ProposalExecuted(uint256 indexed proposalId);

    // ERC-20 State
    string public name = "Advanced Staking Token";
    string public symbol = "AST";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Staking State
    struct StakingPool {
        uint256 apy; // Annual percentage yield (in basis points, e.g., 1000 = 10%)
        uint256 lockDuration; // Lock duration in seconds
        uint256 totalStaked;
        uint256 totalRewardsDistributed;
        bool active;
        uint256 createdAt;
    }

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 poolId;
        uint256 lastClaimTime;
        uint256 accumulatedRewards;
    }

    StakingPool[] public stakingPools;
    mapping(address => mapping(uint256 => Stake)) public userStakes;
    mapping(address => uint256[]) public userPoolIds;

    // Governance State
    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        address proposer;
        bytes callData;
        address target;
    }

    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256) public votingPower;
    uint256 public constant VOTING_DURATION = 3 days;
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10**18; // 1000 tokens

    // Modifiers
    modifier onlyGovernance() {
        require(balanceOf[msg.sender] >= PROPOSAL_THRESHOLD, "Insufficient voting power");
        _;
    }

    modifier validPool(uint256 poolId) {
        require(poolId < stakingPools.length, "Invalid pool");
        require(stakingPools[poolId].active, "Pool not active");
        _;
    }

    constructor() {
        totalSupply = 1000000 * 10**18; // 1M tokens
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);

        // Create initial staking pools
        createStakingPool(500, 30 days); // 5% APY, 30-day lock
        createStakingPool(1000, 90 days); // 10% APY, 90-day lock
        createStakingPool(2000, 365 days); // 20% APY, 1-year lock
    }

    // ERC-20 Functions
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }

    // Staking Functions
    function createStakingPool(uint256 apy, uint256 lockDuration) public {
        require(apy > 0 && apy <= 5000, "Invalid APY"); // Max 50% APY
        require(lockDuration >= 1 days, "Lock duration too short");
        
        stakingPools.push(StakingPool({
            apy: apy,
            lockDuration: lockDuration,
            totalStaked: 0,
            totalRewardsDistributed: 0,
            active: true,
            createdAt: block.timestamp
        }));

        emit PoolCreated(stakingPools.length - 1, apy, lockDuration);
    }

    function stake(uint256 poolId, uint256 amount) external validPool(poolId) {
        require(amount > 0, "Amount must be positive");
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        // Transfer tokens to contract
        balanceOf[msg.sender] -= amount;
        balanceOf[address(this)] += amount;

        // Update user stake
        Stake storage userStake = userStakes[msg.sender][poolId];
        if (userStake.amount > 0) {
            // Claim existing rewards first
            _claimRewards(msg.sender, poolId);
        }

        userStake.amount += amount;
        userStake.timestamp = block.timestamp;
        userStake.poolId = poolId;
        userStake.lastClaimTime = block.timestamp;

        // Update pool
        stakingPools[poolId].totalStaked += amount;

        // Add to user's pool list if new
        bool poolExists = false;
        for (uint256 i = 0; i < userPoolIds[msg.sender].length; i++) {
            if (userPoolIds[msg.sender][i] == poolId) {
                poolExists = true;
                break;
            }
        }
        if (!poolExists) {
            userPoolIds[msg.sender].push(poolId);
        }

        emit Staked(msg.sender, poolId, amount, block.timestamp);
    }

    function unstake(uint256 poolId) external validPool(poolId) {
        Stake storage userStake = userStakes[msg.sender][poolId];
        require(userStake.amount > 0, "No stake found");
        require(
            block.timestamp >= userStake.timestamp + stakingPools[poolId].lockDuration,
            "Lock period not ended"
        );

        uint256 amount = userStake.amount;
        uint256 rewards = calculateRewards(msg.sender, poolId);

        // Claim rewards
        if (rewards > 0) {
            _mint(msg.sender, rewards);
            stakingPools[poolId].totalRewardsDistributed += rewards;
            emit RewardsClaimed(msg.sender, poolId, rewards);
        }

        // Return staked tokens
        balanceOf[address(this)] -= amount;
        balanceOf[msg.sender] += amount;

        // Update state
        stakingPools[poolId].totalStaked -= amount;
        userStake.amount = 0;
        userStake.timestamp = 0;
        userStake.lastClaimTime = 0;

        emit Unstaked(msg.sender, poolId, amount, rewards);
    }

    function claimRewards(uint256 poolId) external validPool(poolId) {
        uint256 rewards = calculateRewards(msg.sender, poolId);
        require(rewards > 0, "No rewards to claim");

        _claimRewards(msg.sender, poolId);
    }

    function _claimRewards(address user, uint256 poolId) internal {
        uint256 rewards = calculateRewards(user, poolId);
        if (rewards > 0) {
            _mint(user, rewards);
            userStakes[user][poolId].lastClaimTime = block.timestamp;
            userStakes[user][poolId].accumulatedRewards += rewards;
            stakingPools[poolId].totalRewardsDistributed += rewards;
            emit RewardsClaimed(user, poolId, rewards);
        }
    }

    function calculateRewards(address user, uint256 poolId) public view returns (uint256) {
        Stake memory userStake = userStakes[user][poolId];
        if (userStake.amount == 0) return 0;

        StakingPool memory pool = stakingPools[poolId];
        uint256 timeElapsed = block.timestamp - userStake.lastClaimTime;
        uint256 annualReward = (userStake.amount * pool.apy) / 10000;
        uint256 reward = (annualReward * timeElapsed) / 365 days;

        return reward;
    }

    // Governance Functions
    function propose(string memory description, address target, bytes memory callData) external onlyGovernance {
        proposals.push(Proposal({
            description: description,
            forVotes: 0,
            againstVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + VOTING_DURATION,
            executed: false,
            proposer: msg.sender,
            callData: callData,
            target: target
        }));

        emit GovernanceProposalCreated(proposals.length - 1, description);
    }

    function vote(uint256 proposalId, bool support) external {
        require(proposalId < proposals.length, "Invalid proposal");
        require(!hasVoted[proposalId][msg.sender], "Already voted");
        require(block.timestamp <= proposals[proposalId].endTime, "Voting ended");

        Proposal storage proposal = proposals[proposalId];
        uint256 votes = balanceOf[msg.sender] + _calculateStakingVotes(msg.sender);

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposal.forVotes += votes;
        } else {
            proposal.againstVotes += votes;
        }

        emit VoteCast(msg.sender, proposalId, support, votes);
    }

    function executeProposal(uint256 proposalId) external {
        require(proposalId < proposals.length, "Invalid proposal");
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting not ended");
        require(!proposal.executed, "Already executed");
        require(proposal.forVotes > proposal.againstVotes, "Proposal rejected");

        proposal.executed = true;
        
        if (proposal.target != address(0) && proposal.callData.length > 0) {
            (bool success, ) = proposal.target.call(proposal.callData);
            require(success, "Execution failed");
        }

        emit ProposalExecuted(proposalId);
    }

    function _calculateStakingVotes(address user) internal view returns (uint256) {
        uint256 totalVotes = 0;
        uint256[] memory poolIds = userPoolIds[user];
        
        for (uint256 i = 0; i < poolIds.length; i++) {
            uint256 poolId = poolIds[i];
            Stake memory userStake = userStakes[user][poolId];
            if (userStake.amount > 0) {
                // Staked tokens count as voting power
                totalVotes += userStake.amount;
            }
        }
        
        return totalVotes;
    }

    // Internal Functions
    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    // View Functions
    function getStakingPools() external view returns (StakingPool[] memory) {
        return stakingPools;
    }

    function getUserStakes(address user) external view returns (Stake[] memory) {
        uint256[] memory poolIds = userPoolIds[user];
        Stake[] memory stakes = new Stake[](poolIds.length);
        
        for (uint256 i = 0; i < poolIds.length; i++) {
            stakes[i] = userStakes[user][poolIds[i]];
        }
        
        return stakes;
    }

    function getProposals() external view returns (Proposal[] memory) {
        return proposals;
    }

    function getTotalStaked() external view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < stakingPools.length; i++) {
            total += stakingPools[i].totalStaked;
        }
        return total;
    }
}
