
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract DecentralizedArbitration is VRFConsumerBaseV2 {
    enum TaskStatus { Open, Taken, Completed, Disputed, Resolved }

    struct Task {
        address creator;
        address worker;
        uint256 reward;
        TaskStatus status;
        uint256[] arbiterVotes; // 1 - worker wins, 0 - creator wins
        address[] arbiters;
        mapping(address => bool) hasVoted;
    }

    uint256 public taskCounter;
    mapping(uint256 => Task) public tasks;

    address[] public arbiterPool; // All staked arbiters
    uint256 public stakeAmount = 100 ether;

    // --- Chainlink VRF Parameters ---
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmations = 3;
    uint32 numWords = 3; // Select 3 arbiters

    constructor(address vrfCoordinator, bytes32 _keyHash, uint64 _subId)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        keyHash = _keyHash;
        subscriptionId = _subId;
    }

    function createTask() external payable {
        Task storage t = tasks[taskCounter];
        t.creator = msg.sender;
        t.reward = msg.value;
        t.status = TaskStatus.Open;
        taskCounter++;
    }

    function acceptTask(uint256 taskId) external {
        Task storage t = tasks[taskId];
        require(t.status == TaskStatus.Open, "Not open");
        t.worker = msg.sender;
        t.status = TaskStatus.Taken;
    }

    function completeTask(uint256 taskId) external {
        Task storage t = tasks[taskId];
        require(msg.sender == t.worker, "Not worker");
        t.status = TaskStatus.Completed;
    }

    function initiateDispute(uint256 taskId) external {
        Task storage t = tasks[taskId];
        require(t.status == TaskStatus.Completed, "Not completed");
        t.status = TaskStatus.Disputed;

        requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        uint256 taskId = taskCounter - 1; // Simplified: last task disputed
        Task storage t = tasks[taskId];

        for (uint i = 0; i < randomWords.length; i++) {
            uint256 index = randomWords[i] % arbiterPool.length;
            t.arbiters.push(arbiterPool[index]);
        }
    }

    function vote(uint256 taskId, bool favorWorker) external {
        Task storage t = tasks[taskId];
        require(t.status == TaskStatus.Disputed, "Not disputed");

        // Only selected arbiters can vote
        bool isArbiter = false;
        for (uint i = 0; i < t.arbiters.length; i++) {
            if (t.arbiters[i] == msg.sender) isArbiter = true;
        }
        require(isArbiter, "Not arbiter");
        require(!t.hasVoted[msg.sender], "Already voted");

        t.hasVoted[msg.sender] = true;
        t.arbiterVotes.push(favorWorker ? 1 : 0);

        if (t.arbiterVotes.length == t.arbiters.length) {
            finalizeDispute(taskId);
        }
    }

    function finalizeDispute(uint256 taskId) internal {
        Task storage t = tasks[taskId];
        uint count = 0;
        for (uint i = 0; i < t.arbiterVotes.length; i++) {
            if (t.arbiterVotes[i] == 1) count++;
        }

        bool workerWins = count > t.arbiterVotes.length / 2;
        address payable receiver = payable(workerWins ? t.worker : t.creator);
        receiver.transfer(t.reward);
        t.status = TaskStatus.Resolved;
    }

    // --- Simplified stake function ---
    function stake() external payable {
        require(msg.value == stakeAmount, "Incorrect stake");
        arbiterPool.push(msg.sender);
    }
}
