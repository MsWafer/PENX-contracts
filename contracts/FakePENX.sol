// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract FakePENX is ERC20, AccessControl {
    uint8 _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 supply,
        uint8 dec
    ) ERC20(name_, symbol_) {
        _decimals = dec;
        _mint(msg.sender, supply * 10**dec);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(uint256 amount, address to) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        _mint(to, amount * 10**_decimals);
    }
}
