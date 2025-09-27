// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract OnchainSummer2025 {
    string public message;
    address public owner;
    uint256 public deploymentTime;
    
    event MessageUpdated(string newMessage, address updatedBy);
    
    constructor(string memory _initialMessage) {
        message = _initialMessage;
        owner = msg.sender;
        deploymentTime = block.timestamp;
    }
    
    function updateMessage(string memory _newMessage) public {
        require(msg.sender == owner, "Only owner can update message");
        message = _newMessage;
        emit MessageUpdated(_newMessage, msg.sender);
    }
    
    function getInfo() public view returns (
        string memory _message,
        address _owner,
        uint256 _deploymentTime,
        uint256 _currentTime
    ) {
        return (message, owner, deploymentTime, block.timestamp);
    }
}
