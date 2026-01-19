const hre = require("hardhat");
const fs = require("fs");

async function main() {
  const Factory = await hre.ethers.getContractFactory("TrainingRegistry");
  const registry = await Factory.deploy();
  await registry.waitForDeployment();

  const address = await registry.getAddress();
  console.log("TrainingRegistry deployed at:", address);

  fs.mkdirSync("addresses", { recursive: true });
  fs.writeFileSync(
    "addresses/localhost.json",
    JSON.stringify({ TrainingRegistry: address }, null, 2)
  );
  console.log("Saved -> addresses/localhost.json");
}

main().then(() => process.exit(0)).catch((e) => {
  console.error(e);
  process.exit(1);
});