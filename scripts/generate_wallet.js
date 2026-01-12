const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

async function main() {
    // Generate a random wallet
    const wallet = ethers.Wallet.createRandom();

    console.log("----------------------------------------------------");
    console.log("New Wallet Generated for Deployment");
    console.log("----------------------------------------------------");
    console.log(`Address:     ${wallet.address}`);
    console.log("----------------------------------------------------");

    // Path to .env file
    const envPath = path.join(__dirname, "..", ".env");

    // Create or append to .env
    const envContent = `PRIVATE_KEY=${wallet.privateKey}\n`;

    try {
        fs.writeFileSync(envPath, envContent, { flag: 'w' });
        console.log(`Private Key saved to: ${envPath}`);
        console.log("Configured hardhat to use this wallet.");
    } catch (error) {
        console.error("Error writing .env file:", error);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
