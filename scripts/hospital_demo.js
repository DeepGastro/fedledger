const hre = require("hardhat");

async function main() {
  // 컨트랙트 주소 로드
  const address =
  require("../interface/addresses/localhost.json").TrainingRegistry;

  // 병원 계정(여기선 Hardhat 기본 2번째 계정 사용)
  const [, hospitalA] = await hre.ethers.getSigners();

  // hospitalA signer로 컨트랙트 붙기
  const registry = await hre.ethers.getContractAt("TrainingRegistry", address, hospitalA);

  // roundId는 중앙이 만든 값을 넣어야 함
  // 방법 1) central_demo 실행 후 출력된 roundId를 그대로 붙여넣기
  // 방법 2) env로 전달: ROUND_ID=... npx hardhat run ...
  const roundIdStr = process.env.ROUND_ID;
  if (!roundIdStr) {
    throw new Error("ROUND_ID env is required. Example: ROUND_ID=123 npx hardhat run scripts/hospital_demo.js --network localhost");
  }
  const roundId = BigInt(roundIdStr);

  // 중앙과 동일한 모델 버전(컨트랙트에서 mismatch면 revert)
  const modelV = hre.ethers.encodeBytes32String("v1.0");

  // 업데이트 해시(지금은 더미)
  const updateHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("dummy_update"));

  // 제출
  const tx = await registry.submitUpdate(roundId, modelV, updateHash);
  const receipt = await tx.wait();

  console.log("✅ Submitted");
  console.log("  - hospital:", hospitalA.address);
  console.log("  - roundId :", roundId.toString());
  console.log("  - txHash  :", receipt.hash);

  // 조회(읽기)
  const sub = await registry.getSubmission(hospitalA.address, roundId);
  console.log("\n📦 getSubmission result:");
  console.log(sub);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});