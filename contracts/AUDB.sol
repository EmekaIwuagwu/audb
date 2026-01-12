// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title AUDB - Australian Dollar Backed Stablecoin
 * @notice ERC20 stablecoin with role-based access control and supply caps
 * @dev Implements ERC20, ERC2612 (Permit), AccessControl, and Pausable
 */
contract AUDB is ERC20, ERC20Permit, AccessControl, Pausable {
    /// @notice Role identifier for minting operations
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role identifier for burning operations
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Role identifier for pausing operations
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Maximum total supply cap (1 billion AUDB)
    uint256 public constant MAX_TOTAL_SUPPLY = 1_000_000_000 * 1e18;

    /// @notice Maximum mint amount per transaction (10 million AUDB)
    uint256 public constant MAX_MINT_PER_TX = 10_000_000 * 1e18;

    /// @notice Emitted when tokens are minted
    event Minted(address indexed to, uint256 amount, address indexed minter);

    /// @notice Emitted when tokens are burned
    event Burned(address indexed from, uint256 amount, address indexed burner);

    /**
     * @notice Initializes the AUDB token with roles
     * @dev Grants DEFAULT_ADMIN_ROLE to deployer
     */
    constructor()
        ERC20("Australian Dollar Backed", "AUDB")
        ERC20Permit("Australian Dollar Backed")
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @notice Mints new AUDB tokens
     * @dev Only callable by addresses with MINTER_ROLE
     * @param to Address to receive minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(
        address to,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) whenNotPaused {
        require(to != address(0), "AUDB: mint to zero address");
        require(amount > 0, "AUDB: zero mint amount");
        require(amount <= MAX_MINT_PER_TX, "AUDB: exceeds max mint per tx");
        require(
            totalSupply() + amount <= MAX_TOTAL_SUPPLY,
            "AUDB: exceeds max total supply"
        );

        _mint(to, amount);
        emit Minted(to, amount, msg.sender);
    }

    /**
     * @notice Burns AUDB tokens
     * @dev Only callable by addresses with BURNER_ROLE
     * @param from Address to burn tokens from
     * @param amount Amount of tokens to burn
     */
    function burn(
        address from,
        uint256 amount
    ) external onlyRole(BURNER_ROLE) whenNotPaused {
        require(from != address(0), "AUDB: burn from zero address");
        require(amount > 0, "AUDB: zero burn amount");

        _burn(from, amount);
        emit Burned(from, amount, msg.sender);
    }

    /**
     * @notice Pauses all token transfers and minting/burning
     * @dev Only callable by addresses with PAUSER_ROLE
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all token operations
     * @dev Only callable by addresses with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Hook that is called before any token transfer
     * @dev Enforces pause functionality
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
