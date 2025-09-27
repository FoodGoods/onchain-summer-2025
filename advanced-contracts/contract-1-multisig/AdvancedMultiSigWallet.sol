// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/console.sol";

/**
 * @title AdvancedMultiSigWallet
 * @dev Advanced multi-signature wallet with governance features
 * @notice Implements time-locked proposals, emergency functions, and flexible threshold management
 */
contract AdvancedMultiSigWallet {
    // Events
    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txIndex,
        address indexed to,
        uint256 value,
        bytes data,
        uint256 executionTime
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    event RequirementChange(uint256 required);
    event EmergencyMode(bool enabled);

    // State variables
    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public required;
    uint256 public constant TIMELOCK_DURATION = 2 days;
    uint256 public constant EMERGENCY_TIMELOCK = 1 hours;
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        uint256 executionTime;
        bool isEmergency;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public confirmations;
    
    bool public emergencyMode;
    uint256 public emergencyThreshold;

    // Modifiers
    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can call this");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "Owner does not exist");
        _;
    }

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner], "Owner already exists");
        _;
    }

    modifier validRequirement(uint256 ownerCount, uint256 _required) {
        require(
            ownerCount >= _required && _required >= 1,
            "Invalid requirement"
        );
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require(confirmations[transactionId][owner], "Transaction not confirmed");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        require(!confirmations[transactionId][owner], "Transaction already confirmed");
        _;
    }

    modifier timelockPassed(uint256 transactionId) {
        require(
            block.timestamp >= transactions[transactionId].executionTime,
            "Timelock not passed"
        );
        _;
    }

    /**
     * @dev Constructor sets initial owners and required confirmations
     * @param _owners Array of initial owner addresses
     * @param _required Number of required confirmations
     */
    constructor(address[] memory _owners, uint256 _required)
        validRequirement(_owners.length, _required)
    {
        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Duplicate owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
        required = _required;
        emergencyThreshold = (_required * 2) / 3 + 1; // 2/3 majority for emergency
    }

    /**
     * @dev Fallback function to receive ETH
     */
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /**
     * @dev Submit a transaction for confirmation
     * @param _to Destination address
     * @param _value ETH value to send
     * @param _data Transaction data
     * @param _isEmergency Whether this is an emergency transaction
     * @return transactionId The ID of the submitted transaction
     */
    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data,
        bool _isEmergency
    ) public ownerExists(msg.sender) returns (uint256 transactionId) {
        uint256 timelock = _isEmergency ? EMERGENCY_TIMELOCK : TIMELOCK_DURATION;
        
        transactionId = transactions.length;
        transactions.push(
            Transaction({
                to: _to,
                value: _value,
                data: _data,
                executed: false,
                confirmations: 0,
                executionTime: block.timestamp + timelock,
                isEmergency: _isEmergency
            })
        );

        emit SubmitTransaction(
            msg.sender,
            transactionId,
            _to,
            _value,
            _data,
            block.timestamp + timelock
        );
    }

    /**
     * @dev Confirm a transaction
     * @param transactionId Transaction ID to confirm
     */
    function confirmTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        notConfirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = true;
        transactions[transactionId].confirmations += 1;

        emit ConfirmTransaction(msg.sender, transactionId);
    }

    /**
     * @dev Execute a confirmed transaction
     * @param transactionId Transaction ID to execute
     */
    function executeTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        timelockPassed(transactionId)
        notExecuted(transactionId)
    {
        Transaction storage txn = transactions[transactionId];
        
        uint256 requiredConfirmations = txn.isEmergency ? emergencyThreshold : required;
        require(
            txn.confirmations >= requiredConfirmations,
            "Insufficient confirmations"
        );

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction execution failed");

        emit ExecuteTransaction(msg.sender, transactionId);
    }

    /**
     * @dev Revoke a confirmation
     * @param transactionId Transaction ID to revoke confirmation for
     */
    function revokeConfirmation(uint256 transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        transactions[transactionId].confirmations -= 1;

        emit RevokeConfirmation(msg.sender, transactionId);
    }

    /**
     * @dev Add a new owner (requires wallet execution)
     * @param owner Address of new owner
     */
    function addOwner(address owner)
        public
        onlyWallet
        ownerDoesNotExist(owner)
        validRequirement(owners.length + 1, required)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /**
     * @dev Remove an owner (requires wallet execution)
     * @param owner Address of owner to remove
     */
    function removeOwner(address owner)
        public
        onlyWallet
        ownerExists(owner)
        validRequirement(owners.length - 1, required)
    {
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length - 1; i++) {
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        owners.pop();
        emit OwnerRemoval(owner);
    }

    /**
     * @dev Change required confirmations (requires wallet execution)
     * @param _required New required confirmations
     */
    function changeRequirement(uint256 _required)
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        required = _required;
        emit RequirementChange(_required);
    }

    /**
     * @dev Toggle emergency mode
     */
    function toggleEmergencyMode() public ownerExists(msg.sender) {
        emergencyMode = !emergencyMode;
        emit EmergencyMode(emergencyMode);
    }

    /**
     * @dev Get transaction count
     * @return count Number of transactions
     */
    function getTransactionCount() public view returns (uint256 count) {
        return transactions.length;
    }

    /**
     * @dev Get owners array
     * @return Array of owner addresses
     */
    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    /**
     * @dev Get transaction details
     * @param transactionId Transaction ID
     * @return to Destination address
     * @return value ETH value
     * @return data Transaction data
     * @return executed Execution status
     * @return confirmations Number of confirmations
     * @return executionTime Execution timestamp
     * @return isEmergency Emergency status
     */
    function getTransaction(uint256 transactionId)
        public
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed,
            uint256 confirmations,
            uint256 executionTime,
            bool isEmergency
        )
    {
        Transaction storage txn = transactions[transactionId];
        return (
            txn.to,
            txn.value,
            txn.data,
            txn.executed,
            txn.confirmations,
            txn.executionTime,
            txn.isEmergency
        );
    }

    /**
     * @dev Get confirmation count for a transaction
     * @param transactionId Transaction ID
     * @return count Number of confirmations
     */
    function getConfirmationCount(uint256 transactionId)
        public
        view
        returns (uint256 count)
    {
        return transactions[transactionId].confirmations;
    }

    /**
     * @dev Check if transaction is confirmed by owner
     * @param transactionId Transaction ID
     * @param owner Owner address
     * @return confirmed Whether transaction is confirmed by owner
     */
    function isConfirmed(uint256 transactionId, address owner)
        public
        view
        returns (bool confirmed)
    {
        return confirmations[transactionId][owner];
    }
}
