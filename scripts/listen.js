const { ethers } = require("ethers");
const abi = require("../abi/TrainingRegistry.abi.json");
const address = require("../interface/addresses/localhost.json").TrainingRegistry;


async function main() {
  const RPC = "http://127.0.0.1:8545";
  const provider = new ethers.JsonRpcProvider(RPC);

  const registry = new ethers.Contract(address, abi, provider);

  console.log("Listening on:", RPC);
  console.log("Contract:", address);

  registry.on("RoundCreated", (roundId, expectedModelVersion, submitDeadline) => {
    console.log("[event] RoundCreated", {
      roundId: roundId.toString(),
      expectedModelVersion,
      submitDeadline: submitDeadline.toString(),
    });
  });

  registry.on("UpdateSubmitted", (hospital, roundId, modelVersion, updateHash) => {
    console.log("[event] UpdateSubmitted", {
      hospital,
      roundId: roundId.toString(),
      modelVersion,
      updateHash,
    });
  });

  registry.on("RoundFinalized", (roundId, aggregatedUpdateHash, newModelVersion) => {
    console.log("[event] RoundFinalized", {
      roundId: roundId.toString(),
      aggregatedUpdateHash,
      newModelVersion,
    });
  });

  // 프로세스가 안 꺼지게 유지
  await new Promise(() => {});
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});