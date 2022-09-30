import { hexStripZeros } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as fs from "fs";
//@ts-ignore
const delay = (ms) => new Promise((res) => setTimeout(res, ms));

//@ts-ignore
module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdc = await deployments.get("FakeUSDC");
  // const usdc = "0x32D97E3452Ed15883EC8FDDd6b8142e4e8e6e6ff";
  const pxlt = await deployments.get("FakePXLT");
  // const pxlt = "0xDA85dF830352C755429b59604CA4924BDad16A44";
  const penx = await deployments.get("FakePENX");
  // const penx = "0xf387AFAA46A0F7676B7214f23Ea6db7929CB1e39";
  const router = "0xd99d1c33f9fc3444f8101754abc46c52416550d1";

  const scheduler = await deployments.get("Scheduler");
  const constructor = [penx.address, pxlt.address, usdc.address, scheduler.address, router];
  let stake = await deploy("Staking", {
    from: deployer,
    args: constructor,
    log: true,
  });
  await delay(10000);
  try {
    await run("verify:verify", {
      address: stake.address,
      constructorArguments: constructor,
    });
  } catch (error) {
    console.log(error)
  }
  
};
module.exports.tags = ["Staking"];
