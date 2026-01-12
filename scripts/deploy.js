const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await hre.ethers.provider.getBalance(deployer.address)).toString());

    // Constants for Fuji Testnet
    const PYTH_ADDRESS = "0x23f0e8FAeE7bbb405E7A7C3d60138FCfd43d7509";
    const AUD_USD_PRICE_ID = "0x67a6f930304d4ccd7452d37c356985a97920786dd675d0b43534a6c429712574";
    const JOE_ROUTER = "0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901";
    const USDC_ADDRESS = "0x5425890298aed601595a70ab815c96711a31bc65";

    console.log("\n=== Deploying AUDB Token ===");
    // 1. Deploy AUDB
    const AUDB = await hre.ethers.getContractFactory("AUDB");
    const audb = await AUDB.deploy();
    await audb.waitForDeployment();
    console.log("✅ AUDB deployed to:", audb.target);

    console.log("\n=== Deploying LiquidityManager ===");
    // 2. Deploy LiquidityManager
    const LiquidityManager = await hre.ethers.getContractFactory("LiquidityManager");
    const liquidityManager = await LiquidityManager.deploy(JOE_ROUTER, audb.target, USDC_ADDRESS);
    await liquidityManager.waitForDeployment();
    console.log("✅ LiquidityManager deployed to:", liquidityManager.target);

    console.log("\n=== Deploying Rebalancer ===");
    // 3. Deploy Rebalancer
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
    console.log("✅ Rebalancer deployed to:", rebalancer.target);

    console.log("\n=== Deploying Vault ===");
    // 4. Deploy Vault
    const Vault = await hre.ethers.getContractFactory("Vault");
    const vault = await Vault.deploy(audb.target, USDC_ADDRESS);
    await vault.waitForDeployment();
    console.log("✅ Vault deployed to:", vault.target);

    console.log("\n=== Deploying Paymaster ===");
    // 5. Deploy Paymaster
    const Paymaster = await hre.ethers.getContractFactory("Paymaster");
    const paymaster = await Paymaster.deploy(audb.target);
    await paymaster.waitForDeployment();
    console.log("✅ Paymaster deployed to:", paymaster.target);

    console.log("\n=== Configuring Access Control Roles ===");

    // Grant MINTER_ROLE to Rebalancer and Vault
    const MINTER_ROLE = await audb.MINTER_ROLE();
    const BURNER_ROLE = await audb.BURNER_ROLE();

    console.log("Granting MINTER_ROLE to Rebalancer...");
    let tx = await audb.grantRole(MINTER_ROLE, rebalancer.target);
    await tx.wait();
    console.log("✅ Rebalancer granted MINTER_ROLE");

    console.log("Granting MINTER_ROLE to Vault...");
    tx = await audb.grantRole(MINTER_ROLE, vault.target);
    await tx.wait();
    console.log("✅ Vault granted MINTER_ROLE");

    console.log("Granting BURNER_ROLE to Rebalancer...");
    tx = await audb.grantRole(BURNER_ROLE, rebalancer.target);
    await tx.wait();
    console.log("✅ Rebalancer granted BURNER_ROLE");

    console.log("Granting BURNER_ROLE to Vault...");
    tx = await audb.grantRole(BURNER_ROLE, vault.target);
    await tx.wait();
    console.log("✅ Vault granted BURNER_ROLE");

    console.log("\n=== Configuring LiquidityManager Ownership ===");
    // Transfer LiquidityManager ownership to Rebalancer
    tx = await liquidityManager.transferOwnership(rebalancer.target);
    await tx.wait();
    console.log("✅ LiquidityManager ownership transferred to Rebalancer");

    console.log("\n╔════════════════════════════════════════════════════════╗");
    console.log("║          DEPLOYMENT COMPLETE - AUDB PROTOCOL           ║");
    console.log("╚════════════════════════════════════════════════════════╝");
    console.log("\n📋 Contract Addresses:");
    console.log("─────────────────────────────────────────────────────────");
    console.log("AUDB Token:         ", audb.target);
    console.log("Rebalancer:         ", rebalancer.target);
    console.log("LiquidityManager:   ", liquidityManager.target);
    console.log("Vault:              ", vault.target);
    console.log("Paymaster:          ", paymaster.target);
    console.log("─────────────────────────────────────────────────────────");
    console.log("\n🔗 Snowtrace Links:");
    console.log("AUDB:               https://testnet.snowtrace.io/address/" + audb.target);
    console.log("Rebalancer:         https://testnet.snowtrace.io/address/" + rebalancer.target);
    console.log("LiquidityManager:   https://testnet.snowtrace.io/address/" + liquidityManager.target);
    console.log("Vault:              https://testnet.snowtrace.io/address/" + vault.target);
    console.log("Paymaster:          https://testnet.snowtrace.io/address/" + paymaster.target);
    console.log("\n✅ All roles configured successfully!");
    console.log("✅ Ready for mainnet after external audit\n");

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
