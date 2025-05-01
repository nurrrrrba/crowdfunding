// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PlatformToken is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 * 10**18;

    constructor() ERC20("CrowdToken", "CRWD") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // Механизм для награды пользователя (например, за выполнение задания)
    function reward(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    // Арбитры могут застейкать токены (можно вызывать из другого контракта)
    mapping(address => uint256) public stakes;

    function stake(uint256 amount) external {
        require(amount > 0, "Stake must be > 0");
        _transfer(msg.sender, address(this), amount);
        stakes[msg.sender] += amount;
    }

    function unstake(uint256 amount) external {
        require(stakes[msg.sender] >= amount, "Not enough stake");
        stakes[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);
    }

    // Проверка стейка (можно вызывать из арбитражного контракта)
    function hasStake(address user, uint256 minimum) external view returns (bool) {
        return stakes[user] >= minimum;
    }
}
