const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AUDB System", function () {
    let AUDB, audb;
    let Rebalancer, rebalancer;
    let LiquidityManager, liquidityManager;
    let MockPyth, mockPyth;
    let Paymaster, paymaster;
    let owner, addr1;

    const PRICE_ID = "0x67a6f930304d4ccd7452d37c356985a97920786dd675d0b43534a6c429712574";
    const MOCK_ROUTER = "0xd7f655E3376cE2D7A2b08fF01Eb3B1023191A901"; // Just an address
    const MOCK_USDC = "0x5425890298aed601595a70ab815c96711a31bc65"; // Just an address

    beforeEach(async function () {
        [owner, addr1] = await ethers.getSigners();

        // Deploy Mock Pyth
        MockPyth = await ethers.getContractFactory("MockPyth");
        mockPyth = await MockPyth.deploy();
        await mockPyth.waitForDeployment();

        // Deploy AUDB
        AUDB = await ethers.getContractFactory("AUDB");
        audb = await AUDB.deploy();
        await audb.waitForDeployment();

        // Deploy LiquidityManager
        LiquidityManager = await ethers.getContractFactory("LiquidityManager");
        liquidityManager = await LiquidityManager.deploy(MOCK_ROUTER, audb.target, MOCK_USDC);
        await liquidityManager.waitForDeployment();

        // Deploy Rebalancer
        Rebalancer = await ethers.getContractFactory("Rebalancer");
        rebalancer = await Rebalancer.deploy(
            mockPyth.target,
            PRICE_ID,
            audb.target,
            liquidityManager.target,
            MOCK_ROUTER,
            MOCK_USDC
        );
        await rebalancer.waitForDeployment();

        // Transfer ownership
        await audb.transferOwnership(rebalancer.target);
    });

    it("Should integrate correctly", async function () {
        expect(await audb.owner()).to.equal(rebalancer.target);
        expect(await rebalancer.audb()).to.equal(audb.target);
    });

    it("Paymaster Validation", async function () {
        const Paymaster = await ethers.getContractFactory("Paymaster");
        paymaster = await Paymaster.deploy(audb.target);

        // 1. Check exchange rate
        expect(await paymaster.exchangeRate()).to.be.gt(0);

        // 2. Validate fails without balance
        // This call is static call for view function
        const res = await paymaster.validatePaymasterUserOp.staticCall(addr1.address, 100);
        // Tuple return: context (bytes), validationData (uint)
        // Failure returns ("", 1)
        expect(res[1]).to.equal(1n);
    });
});
