// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IScheduler {

    function isOperator(address account) external view returns (bool);

    function isAdmin(address account) external view returns(bool);

    function getWorkerRetirementDate(address worker) external view returns(uint256);

}
