const hre = require("hardhat");

async function main() {
  // 컨트랙트 주소 로드
  const address = require("../interface/addresses/localhost.json").TrainingRegistry;

  // 중앙(= owner) 계정
  const [owner] = await hre.ethers.getSigners();

  // owner signer로 컨트랙트 붙기
  const registry = await hre.ethers.getContractAt("TrainingRegistry", address, owner);

  // 체인 시간 기준으로 deadline 설정
  const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
  const deadline = now + 3600;

  // 라운드/모델 버전
  const roundId = BigInt(Date.now());
  const modelV = hre.ethers.encodeBytes32String("v1.0");

  // 라운드 생성
  const tx = await registry.createRound(roundId, modelV, deadline);
  const receipt = await tx.wait();

  console.log("✅ Round created");
  console.log("  - roundId:", roundId.toString());
  console.log("  - modelV :", modelV);
  console.log("  - deadline:", deadline);
  console.log("  - txHash:", receipt.hash);

  // 병원이 쓸 수 있게 roundId 출력(복사해서 hospital_demo에 넣어도 됨)
  console.log("\n👉 Hospital should submit using this roundId:");
  console.log(roundId.toString());
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});