pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract AUDB is ERC20, ERC20Permit, Ownable, Pausable {
    constructor()
        ERC20("Australian Dollar Backed", "AUDB")
        ERC20Permit("Australian Dollar Backed")
        Ownable()
    {}

    function mint(address to, uint256 amount) external onlyOwner whenNotPaused {
        _mint(to, amount);
    }

    function burn(
        address from,
        uint256 amount
    ) external onlyOwner whenNotPaused {
        _burn(from, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
