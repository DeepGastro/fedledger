# FedLedger Chain

연합 학습(Federated Learning) 업데이트를 온체인으로 ثبت하기 위한 Hardhat 기반 스마트 컨트랙트 프로젝트입니다. 병원(참여자)이 라운드별로 모델 업데이트 해시를 제출하고, 관리자가 라운드를 확정하는 흐름을 지원합니다.

## 주요 컨트랙트

- `contracts/TrainingRegistry.sol`
  - 라운드 생성 및 마감 시간 설정
  - 참여자 업데이트 해시 제출(라운드당 1회)
  - 제출 상태 승인/반려 처리
  - 라운드 최종 확정(집계 해시, 새 모델 버전 기록)
  - 제출 내역/참여자 조회

## 빠른 시작

```shell
npm install
npx hardhat compile
npx hardhat test
```

## 참고

- Hardhat Ignition 샘플 모듈이 `ignition/modules/Lock.js`에 남아 있습니다. 실제 배포용으로는 `TrainingRegistry`에 맞는 모듈을 추가하세요.

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.js
```
