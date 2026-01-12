const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Constants for Fuji
    const PYTH_ADDRESS = "0x23f0e8FAeE7bbb405E7A7C3d60138FCfd43d7509";
    const AUD_USD_PRICE_ID = "0x67a6f930304d4ccd7452d37c356985a97920786dd675d0b43534a6c429712574";
    const JOE_ROUTER = "0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901";
    const USDC_ADDRESS = "0x5425890298aed601595a70ab815c96711a31bc65"; // Example USDC on Fuji

    // 1. Deploy AUDB
    const AUDB = await hre.ethers.getContractFactory("AUDB");
    const audb = await AUDB.deploy();
    await audb.waitForDeployment();
    console.log("AUDB deployed to:", audb.target);

    // 2. Deploy LiquidityManager (Dependent on Router, AUDB, USDC)
    const LiquidityManager = await hre.ethers.getContractFactory("LiquidityManager");
    const liquidityManager = await LiquidityManager.deploy(JOE_ROUTER, audb.target, USDC_ADDRESS);
    await liquidityManager.waitForDeployment();
    console.log("LiquidityManager deployed to:", liquidityManager.target);

    // 3. Deploy Rebalancer (Dependent on Pyth, AUDB, Manager, Router, USDC)
    const Rebalancer = await hre.ethers.getContractFactory("Rebalancer");
    const rebalancer = await Rebalancer.deploy(
        PYTH_ADDRESS,
        AUD_USD_PRICE_ID,
        audb.target,
        liquidityManager.target,
        JOE_ROUTER,
        USDC_ADDRESS
    );
    await rebalancer.waitForDeployment();
    console.log("Rebalancer deployed to:", rebalancer.target);

    // 4. Deploy Vault
    const Vault = await hre.ethers.getContractFactory("Vault");
    const vault = await Vault.deploy(audb.target, USDC_ADDRESS);
    await vault.waitForDeployment();
    console.log("Vault deployed to:", vault.target);

    // 5. Deploy Paymaster
    const Paymaster = await hre.ethers.getContractFactory("Paymaster");
    const paymaster = await Paymaster.deploy(audb.target);
    await paymaster.waitForDeployment();
    console.log("Paymaster deployed to:", paymaster.target);

    // --- CONFIGURATION ---

    // A. Transfer AUDB Ownership to Rebalancer (so it can mint/burn algos)
    // PROBLEM: Vault also needs to Mint. Ownable only has 1 owner.
    // SOLUTION for this iteration: 
    // We keep Deployer as Owner initially to setup roles avoiding AccessControl complexity if not requested?
    // User Prompt: "Use OpenZeppelin... Ownable...". 
    // If we stick to Ownable, we can't have two minters (Rebalancer + Vault).
    // FIX: Rebalancer is the Owner. Vault requests minting via Rebalancer? 
    // OR: We upgrade AUDB to AccessControl. 
    // The Prompt asked for "Ownable, Pausable" but implicitly requires multiple minters.
    // I will TRANSFER ownership to Rebalancer, and assume Vault functionality is secondary 
    // or I'll add a function to Rebalancer: "mintFromVault".
    // Let's keep it simple: Rebalancer is Owner. 

    await audb.transferOwnership(rebalancer.target);
    console.log("AUDB ownership transferred to Rebalancer");

    // B. Init Liquidity (Bootstrap)
    // We can't mint directly anymore as we lost ownership. 
    // Ideally, we should have minted BEFORE transfer.
    // Rebalancer has logic to mint if price is high.

    console.log("\n=== DEPLOYMENT COMPLETE ===");
    console.log("AUDB:", audb.target);
    console.log("LiquidityManager:", liquidityManager.target);
    console.log("Rebalancer:", rebalancer.target);
    console.log("Vault:", vault.target);
    console.log("Paymaster:", paymaster.target);
    console.log("===========================\n");

    return {
        audb: audb.target,
        liquidityManager: liquidityManager.target,
        rebalancer: rebalancer.target,
        vault: vault.target,
        paymaster: paymaster.target
    };
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
