import { hexStripZeros } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as fs from "fs"
//@ts-ignore
const delay = ms => new Promise(res => setTimeout(res, ms));

//@ts-ignore
module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const usdc = await deployments.get('FakeUSDC')
  const pxlt = await deployments.get('FakePXLT')
  const scheduler = await deployments.get('Scheduler')
  const constructor = [
    pxlt.address,
    "",
    scheduler.address
  ]
  let stake = await deploy('Scheduler', {
    from: deployer,
    args: constructor,
    log: true
  })
  await delay(10000)
  await run("verify:verify", {
    address: stake.address,
    constructorArguments: constructor
  })
};
module.exports.tags = ['FakeUSDT']

