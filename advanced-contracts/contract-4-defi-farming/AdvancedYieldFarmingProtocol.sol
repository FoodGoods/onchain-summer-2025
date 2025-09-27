// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

/**
 * @title AdvancedYieldFarmingProtocol
 * @dev Advanced DeFi yield farming with multiple pools, auto-compounding, and impermanent loss protection
 * @notice Implements liquidity provision, yield farming, and advanced DeFi mechanisms
 */
contract AdvancedYieldFarmingProtocol {
    // Events
    event PoolCreated(uint256 indexed poolId, address indexed tokenA, address indexed tokenB, uint256 apy);
    event LiquidityAdded(uint256 indexed poolId, address indexed user, uint256 amountA, uint256 amountB, uint256 lpTokens);
    event LiquidityRemoved(uint256 indexed poolId, address indexed user, uint256 lpTokens, uint256 amountA, uint256 amountB);
    event FarmStarted(uint256 indexed poolId, address indexed user, uint256 lpTokens);
    event FarmEnded(uint256 indexed poolId, address indexed user, uint256 rewards);
    event RewardsClaimed(uint256 indexed poolId, address indexed user, uint256 amount);
    event AutoCompoundExecuted(address indexed user, uint256 totalRewards);
    event ImpermanentLossProtectionActivated(uint256 indexed poolId, address indexed user, uint256 protectionAmount);

    // Structs
    struct Pool {
        address tokenA;
        address tokenB;
        uint256 reserveA;
        uint256 reserveB;
        uint256 totalLPTokens;
        uint256 apy; // Annual percentage yield in basis points
        bool isActive;
        uint256 createdAt;
        uint256 totalFeesCollected;
    }

    struct FarmPosition {
        uint256 lpTokens;
        uint256 startTime;
        uint256 lastClaimTime;
        uint256 accumulatedRewards;
        bool isActive;
        uint256 impermanentLossProtection;
    }

    struct AutoCompoundSettings {
        bool enabled;
        uint256 threshold; // Minimum rewards to trigger auto-compound
        uint256 frequency; // Hours between auto-compounds
        uint256 lastExecution;
    }

    // State variables
    Pool[] public pools;
    mapping(uint256 => mapping(address => FarmPosition)) public farmPositions;
    mapping(address => AutoCompoundSettings) public autoCompoundSettings;
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public totalFarmed;
    
    address public rewardToken;
    uint256 public constant MAX_APY = 5000; // 50% max APY
    uint256 public constant IMPERMANENT_LOSS_THRESHOLD = 1000; // 10% threshold
    uint256 public constant AUTO_COMPOUND_FEE = 50; // 0.5% fee for auto-compound
    
    address public owner;
    uint256 public totalRewardsDistributed;
    uint256 public totalFeesCollected;

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier validPool(uint256 poolId) {
        require(poolId < pools.length, "Invalid pool");
        require(pools[poolId].isActive, "Pool not active");
        _;
    }

    modifier hasFarmPosition(uint256 poolId) {
        require(farmPositions[poolId][msg.sender].isActive, "No active farm position");
        _;
    }

    constructor(address _rewardToken) {
        owner = msg.sender;
        rewardToken = _rewardToken;
    }

    // Pool Management
    function createPool(
        address tokenA,
        address tokenB,
        uint256 apy
    ) external onlyOwner {
        require(tokenA != tokenB, "Same token");
        require(apy <= MAX_APY, "APY too high");
        
        pools.push(Pool({
            tokenA: tokenA,
            tokenB: tokenB,
            reserveA: 0,
            reserveB: 0,
            totalLPTokens: 0,
            apy: apy,
            isActive: true,
            createdAt: block.timestamp,
            totalFeesCollected: 0
        }));

        emit PoolCreated(pools.length - 1, tokenA, tokenB, apy);
    }

    // Liquidity Provision
    function addLiquidity(
        uint256 poolId,
        uint256 amountA,
        uint256 amountB
    ) external validPool(poolId) {
        Pool storage pool = pools[poolId];
        require(amountA > 0 && amountB > 0, "Amounts must be positive");

        // Calculate LP tokens based on current reserves
        uint256 lpTokens;
        if (pool.totalLPTokens == 0) {
            // First liquidity provision
            lpTokens = sqrt(amountA * amountB);
        } else {
            // Maintain constant product formula
            uint256 lpTokensA = (amountA * pool.totalLPTokens) / pool.reserveA;
            uint256 lpTokensB = (amountB * pool.totalLPTokens) / pool.reserveB;
            lpTokens = lpTokensA < lpTokensB ? lpTokensA : lpTokensB;
        }

        // Transfer tokens from user
        _transferToken(pool.tokenA, msg.sender, address(this), amountA);
        _transferToken(pool.tokenB, msg.sender, address(this), amountB);

        // Update pool reserves
        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.totalLPTokens += lpTokens;

        emit LiquidityAdded(poolId, msg.sender, amountA, amountB, lpTokens);
    }

    function removeLiquidity(uint256 poolId, uint256 lpTokens) external validPool(poolId) {
        Pool storage pool = pools[poolId];
        require(lpTokens > 0, "Amount must be positive");
        require(lpTokens <= pool.totalLPTokens, "Insufficient LP tokens");

        // Calculate token amounts to return
        uint256 amountA = (lpTokens * pool.reserveA) / pool.totalLPTokens;
        uint256 amountB = (lpTokens * pool.reserveB) / pool.totalLPTokens;

        // Update pool reserves
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.totalLPTokens -= lpTokens;

        // Transfer tokens to user
        _transferToken(pool.tokenA, address(this), msg.sender, amountA);
        _transferToken(pool.tokenB, address(this), msg.sender, amountB);

        emit LiquidityRemoved(poolId, msg.sender, lpTokens, amountA, amountB);
    }

    // Yield Farming
    function startFarming(uint256 poolId, uint256 lpTokens) external validPool(poolId) {
        require(lpTokens > 0, "Amount must be positive");
        
        FarmPosition storage position = farmPositions[poolId][msg.sender];
        require(!position.isActive, "Already farming");

        // Transfer LP tokens from user
        _transferLPTokens(poolId, msg.sender, address(this), lpTokens);

        position.lpTokens = lpTokens;
        position.startTime = block.timestamp;
        position.lastClaimTime = block.timestamp;
        position.accumulatedRewards = 0;
        position.isActive = true;
        position.impermanentLossProtection = _calculateImpermanentLossProtection(poolId, lpTokens);

        emit FarmStarted(poolId, msg.sender, lpTokens);
    }

    function endFarming(uint256 poolId) external validPool(poolId) hasFarmPosition(poolId) {
        FarmPosition storage position = farmPositions[poolId][msg.sender];
        
        // Calculate and claim rewards
        uint256 rewards = calculateRewards(poolId, msg.sender);
        if (rewards > 0) {
            _claimRewards(poolId, msg.sender);
        }

        // Check for impermanent loss protection
        uint256 currentProtection = _calculateImpermanentLossProtection(poolId, position.lpTokens);
        if (currentProtection > position.impermanentLossProtection) {
            uint256 protectionAmount = currentProtection - position.impermanentLossProtection;
            pendingRewards[msg.sender] += protectionAmount;
            emit ImpermanentLossProtectionActivated(poolId, msg.sender, protectionAmount);
        }

        // Return LP tokens
        _transferLPTokens(poolId, address(this), msg.sender, position.lpTokens);

        // Update stats
        totalFarmed[msg.sender] += position.lpTokens;

        // Reset position
        position.isActive = false;
        position.lpTokens = 0;
        position.startTime = 0;
        position.lastClaimTime = 0;

        emit FarmEnded(poolId, msg.sender, rewards);
    }

    function claimRewards(uint256 poolId) external validPool(poolId) hasFarmPosition(poolId) {
        uint256 rewards = calculateRewards(poolId, msg.sender);
        require(rewards > 0, "No rewards to claim");

        _claimRewards(poolId, msg.sender);
    }

    function _claimRewards(uint256 poolId, address user) internal {
        uint256 rewards = calculateRewards(poolId, user);
        if (rewards > 0) {
            pendingRewards[user] += rewards;
            farmPositions[poolId][user].lastClaimTime = block.timestamp;
            farmPositions[poolId][user].accumulatedRewards += rewards;
            totalRewardsDistributed += rewards;
            emit RewardsClaimed(poolId, user, rewards);
        }
    }

    // Auto-Compounding
    function enableAutoCompound(uint256 threshold, uint256 frequency) external {
        require(threshold > 0, "Threshold must be positive");
        require(frequency >= 1, "Frequency must be at least 1 hour");

        autoCompoundSettings[msg.sender] = AutoCompoundSettings({
            enabled: true,
            threshold: threshold,
            frequency: frequency,
            lastExecution: block.timestamp
        });
    }

    function executeAutoCompound() external {
        AutoCompoundSettings storage settings = autoCompoundSettings[msg.sender];
        require(settings.enabled, "Auto-compound not enabled");
        require(
            block.timestamp >= settings.lastExecution + (settings.frequency * 1 hours),
            "Too soon for auto-compound"
        );

        uint256 totalRewards = 0;
        
        // Claim rewards from all active farm positions
        for (uint256 i = 0; i < pools.length; i++) {
            if (farmPositions[i][msg.sender].isActive) {
                uint256 rewards = calculateRewards(i, msg.sender);
                if (rewards > 0) {
                    _claimRewards(i, msg.sender);
                    totalRewards += rewards;
                }
            }
        }

        require(totalRewards >= settings.threshold, "Rewards below threshold");

        // Apply auto-compound fee
        uint256 fee = (totalRewards * AUTO_COMPOUND_FEE) / 10000;
        uint256 compoundAmount = totalRewards - fee;

        // Add compound amount to pending rewards
        pendingRewards[msg.sender] += compoundAmount;
        totalFeesCollected += fee;

        settings.lastExecution = block.timestamp;

        emit AutoCompoundExecuted(msg.sender, totalRewards);
    }

    // Advanced Features
    function calculateRewards(uint256 poolId, address user) public view returns (uint256) {
        FarmPosition memory position = farmPositions[poolId][user];
        if (!position.isActive || position.lpTokens == 0) return 0;

        Pool memory pool = pools[poolId];
        uint256 timeElapsed = block.timestamp - position.lastClaimTime;
        uint256 annualReward = (position.lpTokens * pool.apy) / 10000;
        uint256 reward = (annualReward * timeElapsed) / 365 days;

        return reward;
    }

    function _calculateImpermanentLossProtection(uint256 poolId, uint256 lpTokens) internal view returns (uint256) {
        // Simplified impermanent loss calculation
        // In real implementation, this would be more complex
        Pool memory pool = pools[poolId];
        if (pool.totalLPTokens == 0) return 0;

        uint256 userShare = (lpTokens * 10000) / pool.totalLPTokens;
        return (userShare * pool.totalFeesCollected) / 10000;
    }

    function getPoolInfo(uint256 poolId) external view returns (Pool memory) {
        return pools[poolId];
    }

    function getFarmPosition(uint256 poolId, address user) external view returns (FarmPosition memory) {
        return farmPositions[poolId][user];
    }

    function getPendingRewards(address user) external view returns (uint256) {
        return pendingRewards[user];
    }

    function withdrawRewards() external {
        uint256 amount = pendingRewards[msg.sender];
        require(amount > 0, "No rewards to withdraw");

        pendingRewards[msg.sender] = 0;
        _transferToken(rewardToken, address(this), msg.sender, amount);
    }

    // Internal Functions
    function _transferToken(address token, address from, address to, uint256 amount) internal {
        // Simplified - in real implementation, use actual ERC-20 transfer
        console.log("Transferring %s tokens from %s to %s", amount, from, to);
    }

    function _transferLPTokens(uint256 poolId, address from, address to, uint256 amount) internal {
        // Simplified - in real implementation, transfer actual LP tokens
        console.log("Transferring LP tokens for pool %s from %s to %s", poolId, from, to);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }

    // Emergency Functions
    function emergencyWithdraw(uint256 poolId) external {
        FarmPosition storage position = farmPositions[poolId][msg.sender];
        require(position.isActive, "No active position");

        // Return LP tokens without rewards (emergency)
        _transferLPTokens(poolId, address(this), msg.sender, position.lpTokens);
        position.isActive = false;
        position.lpTokens = 0;
    }

    function updatePoolAPY(uint256 poolId, uint256 newAPY) external onlyOwner {
        require(newAPY <= MAX_APY, "APY too high");
        pools[poolId].apy = newAPY;
    }
}
