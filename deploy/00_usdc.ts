import { hexStripZeros } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as fs from "fs";
//@ts-ignore
const delay = (ms) => new Promise((res) => setTimeout(res, ms));

//@ts-ignore
module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const constructor = ["Fake USDC", "FUSDC", 1000000000000000, 18];
  let stake = await deploy("FakeUSDC", {
    from: deployer,
    args: constructor,
    log: true,
  });
  await delay(10000);
  try {
    await run("verify:verify", {
      address: stake.address,
      constructorArguments: constructor,
      contract: "contracts/FakeUSDC.sol:FakeUSDC",
    });
  } catch (error) {
    console.log("verification error");
  }
};
module.exports.tags = ["FakeUSDC"];
