// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RoleControl is AccessControl {

    bytes32 OPERATOR_ROLE = bytes32("OPERATOR_ROLE");

    modifier onlyAdmin() {
        require(isAdmin(msg.sender));
        _;
    }

    function isOperator(address account) public view returns(bool) {
        return hasRole(OPERATOR_ROLE, account);
    }

    function grantOperator(address account) public onlyAdmin {
        grantRole(OPERATOR_ROLE, account);
    }

    modifier onlyOperator() {
        require(isOperator(msg.sender));
        _;
    }

    function isAdmin(address who) public view returns (bool) {
        return (hasRole(DEFAULT_ADMIN_ROLE, who));
    }

    function grantAdmin(address to) public onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, to);
    }

}
