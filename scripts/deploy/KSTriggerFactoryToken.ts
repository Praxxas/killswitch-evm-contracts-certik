import { Contract, ContractFactory } from 'ethers';
import { ethers } from 'hardhat';

async function main() {
  const name: string = 'TriggerFactory';
  const constructorArgs: Array<string | number | Array<string | number>> = [
    '0xEd4c5dAB9f9F00d98108E877D7a3eA32120b249A',
  ];

  const factory: ContractFactory = await ethers.getContractFactory(name);
  const contract: Contract = await factory.deploy(...constructorArgs);
  await contract.deployed();

  console.log(name + ' deployed to:', contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
