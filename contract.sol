// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

    
    contract Staking {
        
        struct User {
            uint amount;
            uint lastUpdateTime;
            uint reward;
        }

        mapping(address=>User) users;

        uint public totalStaked;
        uint public constant rewardRate = 10;
        uint public rewardPool;
        address private immutable owner;
        bool private paused;
        bool private locked;

        event Staked(address indexed user, uint amount, uint time);
        event UnStaked(address indexed user, uint amount, uint reward, uint time);
        event Claimed(address indexed user, uint amount, uint time);
        event EmergencyWithdraw(address indexed user, uint amount);
        event RewardFunded(uint amount);

        modifier onlyOwner(){
            require(msg.sender == owner,"only owner can call this function");
            _;
        }

        modifier onlyWhenNotPaused() {
            require(paused == false, "contract is paused");
            _;
        }

        modifier nonReentrant() {
            require(!locked, "reentrant");
            locked = true;
            _;
            locked = false;
        }

        constructor() {
            owner = msg.sender;
        }

        function pause() onlyOwner public {
            paused = true;
        }

        function unPause() onlyOwner public {
            paused = false;
        }

        function fundRewards() external payable onlyOwner {
            rewardPool += msg.value;
            emit RewardFunded(msg.value);
        }

        function updateReward(address user) internal {
            User storage u = users[user];
            if (u.lastUpdateTime == 0) {
                u.lastUpdateTime = block.timestamp;
                return;
            }
            if (u.amount == 0) {
                u.lastUpdateTime = block.timestamp;
                return;
            }
            uint pending = (u.amount * rewardRate * (block.timestamp - u.lastUpdateTime)) / 1e18;
            u.reward += pending;
            u.lastUpdateTime = block.timestamp;
        }

        function pendingReward(address user) external view returns (uint) {
            User storage u = users[user];
            if (u.lastUpdateTime == 0) {
                return u.reward;
            }
            uint pending = (u.amount * rewardRate * (block.timestamp - u.lastUpdateTime)) / 1e18;
                return u.reward + pending;
        }

        function stake() external payable onlyWhenNotPaused nonReentrant {
            User storage u = users[msg.sender];
            require(msg.value > 0, "enter amount greater than 0");
            if(u.amount > 0){
                updateReward(msg.sender);
            }
            u.amount += msg.value;
            u.lastUpdateTime = block.timestamp;
            totalStaked += msg.value;
            emit Staked(msg.sender, msg.value, block.timestamp);
        }

        function claim() external onlyWhenNotPaused nonReentrant {
            User storage u = users[msg.sender];
            updateReward(msg.sender);
            uint totalReward = u.reward;
            require(totalReward > 0,"no reward to claim");
            u.reward = 0;
            require(rewardPool >= totalReward, "insufficient reward pool");
            rewardPool -= totalReward;
            (bool success,) = msg.sender.call{value: totalReward}("");
            require(success, "trasnfer failed");
            emit Claimed(msg.sender, totalReward, block.timestamp);
        }

        function unstake() external onlyWhenNotPaused nonReentrant {
            User storage u = users[msg.sender];
            require(u.amount > 0,"nothing to unstake");
            updateReward(msg.sender);
            uint amount = u.amount;
            uint reward = u.reward;
            u.amount = 0;
            u.reward = 0;
            totalStaked -= amount;
            require(rewardPool >= reward, "insufficient reward pool");
            rewardPool -= reward;
            uint total = amount + reward;
            (bool success,) = msg.sender.call{value: total}("");
            require(success,"transfer failed");
            emit UnStaked(msg.sender, amount, reward, block.timestamp);
        }

        receive() external payable {
            rewardPool += msg.value;
            emit RewardFunded(msg.value);
        }

        function emergencyWithdraw() external {
            User storage u = users[msg.sender];
            require(u.amount > 0,"nothing to unstake");
            uint amount = u.amount;
            u.amount = 0;
            u.reward = 0;
            totalStaked -= amount;
            (bool success,) = msg.sender.call{value: amount}("");
            require(success,"transfer failed");
            emit EmergencyWithdraw(msg.sender, amount);
        }

        function getUserInfo() external view returns(address user,uint amount, uint reward,uint pending) {
            return (msg.sender,users[msg.sender].amount, users[msg.sender].reward,this.pendingReward(msg.sender));
        }

        function getContractBalance() external view returns(uint) {
            return address(this).balance;
        }

    }
