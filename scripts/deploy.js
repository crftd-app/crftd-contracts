const hre = require("hardhat");

async function main() {
  const marketFees = "100";

  const Token = await ethers.getContractFactory("MockERC20");
  const token = await Token.deploy("Token", "TKN", 18);

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy();

  const CRFTDRegistry = await ethers.getContractFactory("CRFTDRegistry");
  const marketRegistry = await CRFTDRegistry.deploy(marketFees);

  console.log(`token: "${token.address}",`);
  console.log(`marketplace: "${marketplace.address}",`);
  console.log(`marketRegistry: "${marketRegistry.address}",`);

  console.log(`npx hardhat verify ${token.address} Token TKN 18 --network ${hre.network.name}`);
  console.log(`npx hardhat verify ${marketplace.address} --network ${hre.network.name}`);
  console.log(`npx hardhat verify ${marketRegistry.address} ${marketFees} --network ${hre.network.name}`);

  await marketRegistry.deployed();
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
