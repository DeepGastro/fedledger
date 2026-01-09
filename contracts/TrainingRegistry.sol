// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract TrainingRegistry {
    // ---- Types ----
    enum Status { NONE, SUBMITTED, ACCEPTED, REJECTED }

    struct Submission {
        bytes32 modelVersion;   // bytes32("v1.0") 형태로 저장 권장
        bytes32 updateHash;     // keccak256(ΔW_bytes)
        uint256 submittedAt;    // block.timestamp
        Status status;
    }

    struct Round {
        bytes32 expectedModelVersion;
        uint256 submitDeadline; // unix timestamp
        bool exists;

        bool finalized; //라운드 종료 여부
        bytes32 aggregatedUpdateHash; //중앙 AI가 집계한 결과 해시
        bytes32 newModelVersion; //업데이트된 글로벌 모델 버전
    }

    // ---- Admin ----
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    // ---- Storage ----
    // rounds[roundId] = Round
    mapping(uint256 => Round) public rounds;

    // submissions[hospital][roundId] = Submission
    mapping(address => mapping(uint256 => Submission)) private submissions;

    // roundParticipants[roundId] = list of hospitals who submitted
    mapping(uint256 => address[]) private roundParticipants;

    // ---- Events ----
    event RoundCreated(uint256 indexed roundId, bytes32 expectedModelVersion, uint256 submitDeadline);
    event UpdateSubmitted(address indexed hospital, uint256 indexed roundId, bytes32 modelVersion, bytes32 updateHash);
    event SubmissionStatusSet(address indexed hospital, uint256 indexed roundId, Status status);
    event RoundFinalized(uint256 indexed roundId, bytes32 aggregatedUpdateHash, bytes32 newModelVersion);
    constructor() {
        owner = msg.sender;
    }

    // ---- Admin: create a round ----
    function createRound(
        uint256 roundId,
        bytes32 expectedModelVersion,
        uint256 submitDeadline
    ) external onlyOwner {
        require(!rounds[roundId].exists, "ROUND_EXISTS");
        require(submitDeadline > block.timestamp, "BAD_DEADLINE");

        rounds[roundId] = Round({
            expectedModelVersion: expectedModelVersion,
            submitDeadline: submitDeadline,
            exists: true
        });

        emit RoundCreated(roundId, expectedModelVersion, submitDeadline);
    }
    function finalizeRound(
        uint256 roundId,
        bytes32 aggHash,
        bytes32 newModelVersion
    ) external onlyOwner{
        Round storage r = rounds[roundId];
        require(r.exists, "ROUND_NOT_FOUND");
        require(!r.finalized, "ALEADY_FINALIZED");
        //마감 이후에만 최종 확정(정책 선택)
        require(block.timestamp > r.submitDeadline, "ROUND_NOT_ENDED");

        require(aggHash != bytes32(0), "EMPTY_AGG_HASH");
        require(newModelVersion != bytes32(0), "EMPTY_NEW_VERSION");

        r.finalized = true;
        r.aggregatedUpdateHash = aggHash;
        r.newModelVersion = newModelVersion;

        emit RoundFinalized(roundId, aggHash, newModelVersion);
    }
    // ---- Hospital: submit update hash ----
    function submitUpdate(
        uint256 roundId,
        bytes32 modelVersion,
        bytes32 updateHash
    ) external {
        Round memory r = rounds[roundId];
        require(r.exists, "ROUND_NOT_FOUND");
        require(block.timestamp <= r.submitDeadline, "ROUND_CLOSED");
        require(modelVersion == r.expectedModelVersion, "MODEL_VERSION_MISMATCH");
        require(updateHash != bytes32(0), "EMPTY_HASH");

        // Rule: one submission per (hospital, round)
        Submission storage s = submissions[msg.sender][roundId];
        require(s.status == Status.NONE, "ALREADY_SUBMITTED");

        submissions[msg.sender][roundId] = Submission({
            modelVersion: modelVersion,
            updateHash: updateHash,
            submittedAt: block.timestamp,
            status: Status.SUBMITTED
        });

        roundParticipants[roundId].push(msg.sender);

        emit UpdateSubmitted(msg.sender, roundId, modelVersion, updateHash);
    }

    // ---- Admin: set status (optional) ----
    function setSubmissionStatus(
        address hospital,
        uint256 roundId,
        Status status
    ) external onlyOwner {
        Submission storage s = submissions[hospital][roundId];
        require(s.status != Status.NONE, "NO_SUBMISSION");
        require(status != Status.NONE, "BAD_STATUS");

        s.status = status;
        emit SubmissionStatusSet(hospital, roundId, status);
    }

    // ---- Read helpers ----
    function getSubmission(address hospital, uint256 roundId)
        external
        view
        returns (bytes32 modelVersion, bytes32 updateHash, uint256 submittedAt, Status status)
    {
        Submission memory s = submissions[hospital][roundId];
        return (s.modelVersion, s.updateHash, s.submittedAt, s.status);
    }

    function getRoundParticipants(uint256 roundId) external view returns (address[] memory) {
        return roundParticipants[roundId];
    }
}