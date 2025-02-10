# SayGM Contract

SayGM is a smart contract running on the Ethereum blockchain that allows users to send daily GM (Good Morning) messages.

## 🌟 Features

### 📝 Basic Information
- One GM message per day
- 24-hour waiting period between GMs
- Transaction fee: 0.000029 ETH

### 🔥 Streak System
- Each daily GM increases your streak by 1
- Streak resets if you don't send GM within 48 hours
- Longest streak is permanently recorded
- Higher streak = Higher ranking

### 📨 Special GM Sending
- Send GM to any Ethereum address
- Special GMs also increase your streak
- Recipient's wallet doesn't need to be active

### 🏆 Leaderboard
- Top 100 users are displayed
- Ranking based on current streak
- Total GM count matters for users with same streak
- Minimum 1 streak required to appear

## 📦 Requirements

- Solidity ^0.8.0
- OpenZeppelin Contracts
  - @openzeppelin/contracts/access/Ownable.sol
  - @openzeppelin/contracts/security/ReentrancyGuard.sol
  - @openzeppelin/contracts/security/Pausable.sol
  - @openzeppelin/contracts/utils/Address.sol

## 🔒 Security Features

- ReentrancyGuard: Protection against reentrancy attacks
- Pausable: Ability to pause contract in emergencies
- Ownable: Authorization for admin functions
- Address library for secure fund transfers

## 📊 Contract Functions

### User Functions
- `sayGM(string message)`: Send GM to yourself
- `sayGMTo(address recipient, string message)`: Send GM to another address
- `getUserStats(address user)`: View user statistics
- `getUserRank(address user)`: View user's ranking
- `getTopUsers(uint256 n)`: List top n users

### Admin Functions
- `setFeeRecipient(address newFeeRecipient)`: Update fee recipient address

## 📜 License

This project is licensed under the MIT License. 