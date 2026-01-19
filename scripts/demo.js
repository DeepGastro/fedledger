const hre = require("hardhat");

async function main() {
  const address = require("../addresses/localhost.json").TrainingRegistry;

  const [owner, hospitalA] = await hre.ethers.getSigners();
  const registry = await hre.ethers.getContractAt("TrainingRegistry", address, owner);

  const now = (await hre.ethers.provider.getBlock("latest")).timestamp;
  const deadline = now + 3600;

  const roundId = BigInt(Date.now());
  const modelV = hre.ethers.encodeBytes32String("v1.0");
  const updateHash = hre.ethers.keccak256(hre.ethers.toUtf8Bytes("dummy_update"));

  await (await registry.createRound(roundId, modelV, deadline)).wait();
  console.log("Round created");

  await (await registry.connect(hospitalA).submitUpdate(roundId, modelV, updateHash)).wait();
  console.log("Submitted");

  const sub = await registry.getSubmission(hospitalA.address, roundId);
  console.log("Submission:", sub);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });