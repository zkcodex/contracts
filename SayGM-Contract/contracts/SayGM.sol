// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title SayGM
 * @dev Smart contract that allows users to send "SayGM" messages on-chain,
 * with a fee requirement and a time limit between messages.
 * It includes streak tracking, leaderboard functionality, and additional security features.
 * Fees are accumulated in the contract and can be withdrawn to an address specified by the owner.
 */
contract SayGM is Ownable, ReentrancyGuard, Pausable {
    using Address for address payable;

    // Basic state variables
    mapping(address => uint256) public lastGm;
    mapping(address => uint256) public totalGMs;        // Total GM count
    mapping(address => uint256) public longestStreak;   // Longest streak
    mapping(address => uint256) public currentStreak;   // Current streak

    // Structure for the leaderboard
    struct UserStats {
        address userAddress;
        uint256 currentStreak;
        uint256 longestStreak;
        uint256 totalGMs;
    }
    
    UserStats[] public leaderboard;
    mapping(address => uint256) private leaderboardIndex;
    uint256 public constant MAX_LEADERBOARD_SIZE = 100;

    // Contract settings
    address public feeRecipient;
    uint256 public gmFee;
    uint256 public timeLimit;
    
    // Event declarations
    event SayGMEvent(
        address indexed sender,
        address indexed receiver,
        string message,
        uint256 timestamp
    );
    event FeeRecipientUpdated(address indexed previousRecipient, address indexed newRecipient);
    event GMFeeUpdated(uint256 previousFee, uint256 newFee);
    event TimeLimitUpdated(uint256 previousTimeLimit, uint256 newTimeLimit);
    event FeesWithdrawn(address indexed recipient, uint256 amount);
    event StreakUpdated(address indexed user, uint256 newStreak);
    event NewLongestStreak(address indexed user, uint256 newRecord);
    event LeaderboardUpdated(address indexed user, uint256 rank);

    constructor(address _feeRecipient) Ownable(msg.sender) {
        require(_feeRecipient != address(0), "SayGM: Invalid fee recipient");
        feeRecipient = _feeRecipient;
        gmFee = 0.000029 ether;
        timeLimit = 24 hours;
    }

    function sayGM(string calldata message) external payable nonReentrant whenNotPaused {
        require(msg.value == gmFee, "SayGM: Incorrect ETH fee");
        require(block.timestamp >= lastGm[msg.sender] + timeLimit, "SayGM: Wait before sending another GM");
        _processGM(msg.sender, msg.sender, message);
    }

    function sayGMTo(address recipient, string calldata message) external payable nonReentrant whenNotPaused {
        require(msg.value == gmFee, "SayGM: Incorrect ETH fee");
        require(recipient != address(0), "SayGM: Cannot send to zero address");
        require(block.timestamp >= lastGm[msg.sender] + timeLimit, "SayGM: Wait before sending another GM");
        _processGM(msg.sender, recipient, message);
    }

    function _processGM(address sender, address recipient, string calldata message) internal {
        uint256 previousGmTime = lastGm[sender];
        _updateStreak(sender, previousGmTime);
        lastGm[sender] = block.timestamp;
        _updateLeaderboard(sender);
        emit SayGMEvent(sender, recipient, message, block.timestamp);
    }

    function _updateStreak(address user, uint256 previousGmTime) internal {
        uint256 currentTime = block.timestamp;
        
        if (totalGMs[user] == 0) {
            currentStreak[user] = 1;
            longestStreak[user] = 1;
        } else {
            uint256 daysSinceLastGm = (currentTime - previousGmTime) / 86400;
            
            if (daysSinceLastGm <= 1) {
                currentStreak[user]++;
                if (currentStreak[user] > longestStreak[user]) {
                    longestStreak[user] = currentStreak[user];
                    emit NewLongestStreak(user, longestStreak[user]);
                }
            } else {
                currentStreak[user] = 1;
            }
        }
        
        totalGMs[user]++;
        emit StreakUpdated(user, currentStreak[user]);
    }

    function _updateLeaderboard(address user) internal {
        UserStats memory stats = UserStats({
            userAddress: user,
            currentStreak: currentStreak[user],
            longestStreak: longestStreak[user],
            totalGMs: totalGMs[user]
        });

        if (leaderboardIndex[user] == 0) {
            if (leaderboard.length < MAX_LEADERBOARD_SIZE) {
                leaderboard.push(stats);
                leaderboardIndex[user] = leaderboard.length;
                _sortLeaderboard();
            } else {
                if (stats.currentStreak > leaderboard[leaderboard.length - 1].currentStreak) {
                    address replacedUser = leaderboard[leaderboard.length - 1].userAddress;
                    leaderboard[leaderboard.length - 1] = stats;
                    leaderboardIndex[replacedUser] = 0;
                    leaderboardIndex[user] = leaderboard.length;
                    _sortLeaderboard();
                }
            }
        } else {
            uint256 idx = leaderboardIndex[user] - 1;
            leaderboard[idx] = stats;
            _sortLeaderboard();
        }

        emit LeaderboardUpdated(user, leaderboardIndex[user]);
    }

    function _sortLeaderboard() internal {
        uint256 n = leaderboard.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (leaderboard[j].currentStreak < leaderboard[j + 1].currentStreak) {
                    UserStats memory temp = leaderboard[j];
                    leaderboard[j] = leaderboard[j + 1];
                    leaderboard[j + 1] = temp;
                    leaderboardIndex[leaderboard[j].userAddress] = j + 1;
                    leaderboardIndex[leaderboard[j + 1].userAddress] = j + 2;
                }
            }
        }
    }

    function getTopUsers(uint256 n) external view returns (UserStats[] memory) {
        require(n > 0 && n <= leaderboard.length, "SayGM: Invalid number of users requested");
        UserStats[] memory topUsers = new UserStats[](n);
        for (uint256 i = 0; i < n; i++) {
            topUsers[i] = leaderboard[i];
        }
        return topUsers;
    }

    function getUserStats(address user) external view returns (UserStats memory) {
        return UserStats({
            userAddress: user,
            currentStreak: currentStreak[user],
            longestStreak: longestStreak[user],
            totalGMs: totalGMs[user]
        });
    }

    function getUserRank(address user) external view returns (uint256) {
        uint256 index = leaderboardIndex[user];
        require(index > 0, "SayGM: User not in leaderboard");
        return index;
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(newFeeRecipient != address(0), "SayGM: Invalid fee recipient");
        emit FeeRecipientUpdated(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }
} 