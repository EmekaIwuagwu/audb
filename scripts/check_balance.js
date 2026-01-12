const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
    const address = "0xC707Fb62519578a1C7715002F08CA69cE1FCc58d";
    const balance = await ethers.provider.getBalance(address);
    console.log(`Balance of ${address}: ${ethers.formatEther(balance)} AVAX`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
