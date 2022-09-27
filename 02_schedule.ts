import { getContractAddress, hexStripZeros } from "ethers/lib/utils";
import { ethers, run } from "hardhat";
import * as fs from "fs"
//@ts-ignore
const delay = ms => new Promise(res => setTimeout(res, ms));

//@ts-ignore
module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const token = await deployments.get('FakeUSDC')
  const constructor = [
    token.address,
    "0x06eB448efC79a595F30366257BE5F6575097ad4D",
    "0x06eB448efC79a595F30366257BE5F6575097ad4D"
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
module.exports.tags = ['Scheduler']

