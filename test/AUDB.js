const { expect } = require("chai");
const { ethers } = require("hardhat");

// Production Test Suite
// Since we cannot mock Pyth in a pure production environment without forking,
// these tests verify the structural integrity (deployment, ownership, configuration) 
// rather than simulating price feeds with mocks.

describe("AUDB Production Integrity", function () {
    let AUDB, audb;
    let Rebalancer, rebalancer;
    let LiquidityManager, liquidityManager;
    let owner, addr1;

    // Real Fuji Addresses
    const PYTH_ADDRESS = "0x23f0e8FAeE7bbb405E7A7C3d60138FCfd43d7509";
    const AUD_USD_PRICE_ID = "0x67a6f930304d4ccd7452d37c356985a97920786dd675d0b43534a6c429712574";
    const JOE_ROUTER = "0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901";
    const USDC_ADDRESS = "0x5425890298aed601595a70ab815c96711a31bc65";

    beforeEach(async function () {
        [owner, addr1] = await ethers.getSigners();

        // 1. Deploy AUDB
        AUDB = await ethers.getContractFactory("AUDB");
        audb = await AUDB.deploy();
        await audb.waitForDeployment();

        // 2. Deploy LiquidityManager
        LiquidityManager = await ethers.getContractFactory("LiquidityManager");
        liquidityManager = await LiquidityManager.deploy(JOE_ROUTER, audb.target, USDC_ADDRESS);
        await liquidityManager.waitForDeployment();

        // 3. Deploy Rebalancer
        Rebalancer = await ethers.getContractFactory("Rebalancer");
        rebalancer = await Rebalancer.deploy(
            PYTH_ADDRESS,
            AUD_USD_PRICE_ID,
            audb.target,
            liquidityManager.target,
            JOE_ROUTER,
            USDC_ADDRESS
        );
        await rebalancer.waitForDeployment();

        // 4. Transfer ownership
        await audb.transferOwnership(rebalancer.target);
    });

    it("Should have correct ownership", async function () {
        // Rebalancer must own AUDB to mint/burn
        expect(await audb.owner()).to.equal(rebalancer.target);
    });

    it("Should have correct dependencies linked", async function () {
        expect(await rebalancer.audb()).to.equal(audb.target);
        expect(await rebalancer.liquidityManager()).to.equal(liquidityManager.target);
        expect(await rebalancer.pyth()).to.equal(PYTH_ADDRESS);
    });

    it("Should have correct router in LiquidityManager", async function () {
        expect(await liquidityManager.router()).to.equal(JOE_ROUTER);
    });
});
