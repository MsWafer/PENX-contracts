import { getContractAddress, hexStripZeros } from "ethers/lib/utils";
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
  // const usdc = "0x32D97E3452Ed15883EC8FDDd6b8142e4e8e6e6ff";
  // const pxlt = "0xDA85dF830352C755429b59604CA4924BDad16A44";
  const constructor = [
    usdc.address,
    pxlt.address,
    "0x62F650c0eE84E3a1998A2EEe042a12D9E9728843",
    "0x62F650c0eE84E3a1998A2EEe042a12D9E9728843",
    "0xd99d1c33f9fc3444f8101754abc46c52416550d1"
  ]
  let stake = await deploy('Scheduler', {
    from: deployer,
    args: constructor,
    log: true
  })
  await delay(10000)
  try {
    await run("verify:verify", {
      address: stake.address,
      constructorArguments: constructor,
    });
  } catch (error) {
    console.log(error)
  }
};
module.exports.tags = ['Scheduler']

