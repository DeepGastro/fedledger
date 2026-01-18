// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract TrainingRegistry {
    // ---- Types ----
    //제출 상태
    enum Status {
        NONE, //아직 제출 안함
        SUBMITTED, //병원이 제출 완료
        ACCEPTED, //운영자가 이 제출 인정
        REJECTED //운영자가 이 제출 거절
    }
    //병원 한 곳의 제출 한 건
    struct Submission {
        bytes32 modelVersion; // 병원이 학습에 사용한 기준 모델 버전 bytes32("v1.0") 형태로 저장 권장
        bytes32 updateHash; // 병원이 만든 업데이트(가중치)의 해시 keccak256(ΔW_bytes)
        uint256 submittedAt; // 제출한 시간 block.timestamp
        Status status; //상태
    }
    //학습 라운드 1개
    struct Round {
        bytes32 expectedModelVersion; //이번 라운드에서 병원들이 반드시 써야 하는 기준 모델 버전
        uint256 submitDeadline; // 제출 마감 시간 unix timestamp
        bool exists; //라운드 존재 여부(생성 됐는지)
        bool finalized; //라운드 종료 여부
        bytes32 aggregatedUpdateHash; //중앙 AI가 집계한 결과 해시
        bytes32 newModelVersion; //업데이트된 글로벌 모델 버전
    }

    // ---- Admin ---- 권한 구조
    address public owner; //배포한 사람(중앙 운영자)

    //운영자만 가능한 함수 제한
    /*
    라운드 만들기(createRound)
    제출 상태 바꾸기(setSubmissionStatus)
    라운드 최종 확정(finalizeRound)
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "ONLY_OWNER");
        _;
    }

    // ---- Storage ---- 저장소
    // rounds[roundId] = Round, 라운드 정보 저장
    mapping(uint256 => Round) public rounds;

    // submissions[hospital][roundId] = Submission, 이 병원이 뭘 제출했는지 저장
    mapping(address => mapping(uint256 => Submission)) private submissions;

    // roundParticipants[roundId] = list of hospitals who submitted, 그 라운드에 제출한 병원 주소 목록
    mapping(uint256 => address[]) private roundParticipants;

    // ---- Events ---- 로그/추적용
    //라운드 생성됨
    event RoundCreated(
        uint256 indexed roundId,
        bytes32 expectedModelVersion,
        uint256 submitDeadline
    );
    //병원이 제출함
    event UpdateSubmitted(
        address indexed hospital,
        uint256 indexed roundId,
        bytes32 modelVersion,
        bytes32 updateHash
    );
    //운영자가 상태 변경함
    event SubmissionStatusSet(
        address indexed hospital,
        uint256 indexed roundId,
        Status status
    );
    //운영자가 라운드 확정함
    event RoundFinalized(
        uint256 indexed roundId,
        bytes32 aggregatedUpdateHash,
        bytes32 newModelVersion
    );
    constructor() {
        owner = msg.sender;
    }

    // ---- Admin: create a round ----
    function createRound(
        uint256 roundId,
        bytes32 expectedModelVersion,
        uint256 submitDeadline
    ) external onlyOwner {
        require(!rounds[roundId].exists, "ROUND_EXISTS"); //이미 있으면 막음
        require(submitDeadline > block.timestamp, "BAD_DEADLINE"); //마감이 미래여야함

        Round storage r = rounds[roundId];
        r.expectedModelVersion = expectedModelVersion;
        r.submitDeadline = submitDeadline;
        r.exists = true;
        r.finalized = false;
        r.aggregatedUpdateHash = bytes32(0);
        r.newModelVersion = bytes32(0);

        emit RoundCreated(roundId, expectedModelVersion, submitDeadline);
    }
    function finalizeRound(
        uint256 roundId,
        bytes32 aggHash,
        bytes32 newModelVersion
    ) external onlyOwner {
        Round storage r = rounds[roundId];
        require(r.exists, "ROUND_NOT_FOUND");
        require(!r.finalized, "ALREADY_FINALIZED");
        //마감 이후에만 최종 확정(정책 선택)
        require(block.timestamp > r.submitDeadline, "ROUND_NOT_ENDED");

        require(aggHash != bytes32(0), "EMPTY_AGG_HASH");
        require(newModelVersion != bytes32(0), "EMPTY_NEW_VERSION");
        //통과하면 라운드 확정
        r.finalized = true;
        //집계 결과 해시/새 버전 기록
        r.aggregatedUpdateHash = aggHash;
        r.newModelVersion = newModelVersion;
        //RoundFinalized 이벤트
        emit RoundFinalized(roundId, aggHash, newModelVersion);
    }
    // ---- Hospital: submit update hash ---- 병원이 제출
    function submitUpdate(
        uint256 roundId,
        bytes32 modelVersion,
        bytes32 updateHash
    ) external {
        Round storage r = rounds[roundId];
        //제출 조건 엄격
        //라운드가 존재해야함
        require(r.exists, "ROUND_NOT_FOUND");
        //라운드 finalize 전이어야 함
        require(!r.finalized, "ROUND_FINALIZED");
        //마감 전이어야함
        require(block.timestamp <= r.submitDeadline, "ROUND_CLOSED");
        //병원이 제출한 modelVersion이 라운드의 expectedModelVersion과 같아야함
        require(
            modelVersion == r.expectedModelVersion,
            "MODEL_VERSION_MISMATCH"
        );
        //해시는 0이면 안됨
        require(updateHash != bytes32(0), "EMPTY_HASH");

        // Rule: one submission per (hospital, round)
        //같은 병원은 같은 라운드에 1번만
        Submission storage s = submissions[msg.sender][roundId];
        require(s.status == Status.NONE, "ALREADY_SUBMITTED");
        //다 통과하면 submisiions[msg.sender][roundID]에 기록
        //roundParticipants[roundId]에 병원 주소 추가
        //UpdateSubmitted 이벤트
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
        //제출이 있어야함
        require(s.status != Status.NONE, "NO_SUBMISSION");
        //NONE 으로 바꾸는 것 금지
        require(status != Status.NONE, "BAD_STATUS");
        //상태 변경 후 이벤트
        s.status = status;
        emit SubmissionStatusSet(hospital, roundId, status);
    } //운영자가 제출을 검수해서 ACCEPTED/REJECTED 찍어줄 수 있음

    // ---- Read helpers ---- 조회함수
    //그 병원의 제출 내용/상태 반환
    function getSubmission(
        address hospital,
        uint256 roundId
    )
        external
        view
        returns (
            bytes32 modelVersion,
            bytes32 updateHash,
            uint256 submittedAt,
            Status status
        )
    {
        Submission memory s = submissions[hospital][roundId];
        return (s.modelVersion, s.updateHash, s.submittedAt, s.status);
    }
    //제출한 병원 주소 배열 반환
    function getRoundParticipants(
        uint256 roundId
    ) external view returns (address[] memory) {
        return roundParticipants[roundId];
    }
}
