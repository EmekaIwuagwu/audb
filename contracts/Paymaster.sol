// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AUDB.sol";

// Minimal interface for ERC-4337 Paymaster
// In a real Paymaster, we would inherit from BasePaymaster (Account Abstraction SDK)
contract Paymaster is Ownable {
    IERC20 public audb;
    uint256 public exchangeRate; // AUDB per AVAX (e.g., 50 AUDB = 1 AVAX). Scaled 1e18? Or direct ratio?
    // Let's say exchangeRate is how many WEI of AUDB for 1 WEI of AVAX.
    // If 1 AVAX ($50) and 1 AUDB ($0.65).
    // 1 AVAX = 76.9 AUDB.
    // exchangeRate = 76.9 * 1e18.

    event GasPaid(address indexed user, uint256 costInAudb, uint256 costInAvax);

    constructor(address _audb) Ownable() {
        audb = IERC20(_audb);
        exchangeRate = 77 * 1e18; // Default approx
    }

    // Called by EntryPoint to check if Paymaster is willing to pay.
    // In production, validatPaymasterUserOp returns a context calling _postOp to actually pay.
    // Since we don't have the full AA EntryPoint here, we simulate the payment logic.
    function validatePaymasterUserOp(
        address userSender,
        uint256 requiredPreFund
    ) external returns (bytes memory context, uint256 validationData) {
        // 1. Calculate cost in AUDB
        // cost = requiredPreFund (AVAX) * exchangeRate / 1e18
        uint256 costInAudb = (requiredPreFund * exchangeRate) / 1e18;

        // 2. Check if user has approved enough AUDB
        if (audb.allowance(userSender, address(this)) < costInAudb) {
            // Failure: User didn't approve tokens
            // Return SIG_VALIDATION_FAILED (1)
            return ("", 1);
        }

        // 3. Check if user has balance
        if (audb.balanceOf(userSender) < costInAudb) {
            return ("", 1);
        }

        // Success. In a real paymaster we would reserve funds here.
        return (abi.encode(userSender, costInAudb, requiredPreFund), 0);
    }

    // Called after operation execution to actually take payment
    function postOp(
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external {
        (
            address userSender,
            uint256 estimatedAudbCost,
            uint256 estimatedAvaxCost
        ) = abi.decode(context, (address, uint256, uint256));

        // Re-calculate actual cost
        // Note: Production paymasters manage refunds.
        uint256 actualAudbCost = (actualGasCost * exchangeRate) / 1e18;

        require(
            audb.transferFrom(userSender, address(this), actualAudbCost),
            "Payment failed"
        );

        emit GasPaid(userSender, actualAudbCost, actualGasCost);
    }

    // Admin sets rate (or use Oracle!)
    function setExchangeRate(uint256 _rate) external onlyOwner {
        exchangeRate = _rate;
    }

    function withdraw(address payable to, uint256 amount) external onlyOwner {
        to.transfer(amount);
    }

    function withdrawTokens(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }

    // Allow depositing AVAX to cover gas fees for the EntryPoint to use
    receive() external payable {}
    function deposit() external payable {}
}
