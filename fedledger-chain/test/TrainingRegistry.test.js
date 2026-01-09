const { expect } = require("chai");
const { ethers } = require("hardhat");

function toBytes32(str) {
  // "v1.0" 같은 짧은 문자열을 bytes32로
  return ethers.encodeBytes32String(str);
}

describe("TrainingRegistry", function () {
  it("creates round and accepts one submission per hospital", async function () {
    const [owner, hospA] = await ethers.getSigners();

    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 12;
    const modelV = toBytes32("v1.0");
    const deadline = (await ethers.provider.getBlock("latest")).timestamp + 3600;

    await expect(reg.createRound(roundId, modelV, deadline))
      .to.emit(reg, "RoundCreated");

    const fakeUpdateHash = ethers.keccak256(ethers.toUtf8Bytes("deltaW_A_bytes_dummy"));

    await expect(reg.connect(hospA).submitUpdate(roundId, modelV, fakeUpdateHash))
      .to.emit(reg, "UpdateSubmitted");

    // duplicate submit should fail
    await expect(reg.connect(hospA).submitUpdate(roundId, modelV, fakeUpdateHash))
      .to.be.revertedWith("ALREADY_SUBMITTED");
  });

  it("rejects mismatched modelVersion", async function () {
    const [owner, hospA] = await ethers.getSigners();

    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 1;
    const modelV = toBytes32("v1.0");
    const wrongV = toBytes32("v2.0");
    const deadline = (await ethers.provider.getBlock("latest")).timestamp + 3600;

    await reg.createRound(roundId, modelV, deadline);

    const fakeUpdateHash = ethers.keccak256(ethers.toUtf8Bytes("dummy"));

    await expect(reg.connect(hospA).submitUpdate(roundId, wrongV, fakeUpdateHash))
      .to.be.revertedWith("MODEL_VERSION_MISMATCH");
  });
});

describe("finalizeRound", function () {
  it("only owner can finalize", async function () {
    const [owner, hospA] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 100;
    const v1 = toBytes32("v1.0");
    const latest = await ethers.provider.getBlock("latest");
    const deadline = latest.timestamp + 1;

    await reg.createRound(roundId, v1, deadline);

    // 시간 이동 (마감 이후)
    await ethers.provider.send("evm_increaseTime", [2]);
    await ethers.provider.send("evm_mine");

    const aggHash = ethers.keccak256(ethers.toUtf8Bytes("agg"));
    const v2 = toBytes32("v1.1");

    await expect(
      reg.connect(hospA).finalizeRound(roundId, aggHash, v2)
    ).to.be.revertedWith("ONLY_OWNER");
  });

  it("cannot finalize before deadline", async function () {
    const [owner] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 101;
    const v1 = toBytes32("v1.0");
    const latest = await ethers.provider.getBlock("latest");
    const deadline = latest.timestamp + 3600;

    await reg.createRound(roundId, v1, deadline);

    const aggHash = ethers.keccak256(ethers.toUtf8Bytes("agg"));
    const v2 = toBytes32("v1.1");

    await expect(
      reg.finalizeRound(roundId, aggHash, v2)
    ).to.be.revertedWith("ROUND_NOT_ENDED");
  });

  it("cannot finalize twice", async function () {
    const [owner] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 102;
    const v1 = toBytes32("v1.0");
    const latest = await ethers.provider.getBlock("latest");
    const deadline = latest.timestamp + 1;

    await reg.createRound(roundId, v1, deadline);

    await ethers.provider.send("evm_increaseTime", [2]);
    await ethers.provider.send("evm_mine");

    const aggHash = ethers.keccak256(ethers.toUtf8Bytes("agg"));
    const v2 = toBytes32("v1.1");

    await reg.finalizeRound(roundId, aggHash, v2);

    await expect(
      reg.finalizeRound(roundId, aggHash, v2)
    ).to.be.revertedWith("ALREADY_FINALIZED");
  });
});

describe("submitUpdate additional rules", function () {
  it("reverts if submit after deadline", async function () {
    const [owner, hospA] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 200;
    const v1 = toBytes32("v1.0");
    const latest = await ethers.provider.getBlock("latest");
    const deadline = latest.timestamp + 1;

    await reg.createRound(roundId, v1, deadline);

    await ethers.provider.send("evm_increaseTime", [2]);
    await ethers.provider.send("evm_mine");

    const hash = ethers.keccak256(ethers.toUtf8Bytes("delta"));

    await expect(
      reg.connect(hospA).submitUpdate(roundId, v1, hash)
    ).to.be.revertedWith("ROUND_CLOSED");
  });

  it("reverts submit after round finalized", async function () {
    const [owner, hospA] = await ethers.getSigners();
    const Registry = await ethers.getContractFactory("TrainingRegistry");
    const reg = await Registry.deploy();

    const roundId = 201;
    const v1 = toBytes32("v1.0");
    const latest = await ethers.provider.getBlock("latest");
    const deadline = latest.timestamp + 1;

    await reg.createRound(roundId, v1, deadline);

    await ethers.provider.send("evm_increaseTime", [2]);
    await ethers.provider.send("evm_mine");

    const aggHash = ethers.keccak256(ethers.toUtf8Bytes("agg"));
    const v2 = toBytes32("v1.1");
    await reg.finalizeRound(roundId, aggHash, v2);

    const hash = ethers.keccak256(ethers.toUtf8Bytes("delta"));

    await expect(
      reg.connect(hospA).submitUpdate(roundId, v1, hash)
    ).to.be.revertedWith("ROUND_FINALIZED");
  });
});

