// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./mixins/RoleControl.sol";

contract Scheduler is RoleControl {
    IERC20 USDC;
    bool public isPaused = false;

    uint256 public amountThisIteration;

    mapping(address => uint256) workerRetirementDate;
    mapping(address => bool) isExistingWorker;

    event ScheduleCreated(string ipfs, address contriburor);

    modifier isNotPaused() {
        require(!isPaused);
        _;
    }

    modifier isValidDepositDate() {
        require(
            _timestampToDate(block.timestamp) < 16,
            "Can only deposit before 16th of each month"
        );
        _;
    }

    constructor(
        IERC20 _USDC,
        address _admin,
        address _operator
    ) {
        USDC = _USDC;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
        _setupRole(OPERATOR_ROLE, _operator);
    }

    function createSchedule(
        address[] memory workers,
        uint256[] memory amounts,
        uint256[] memory retirements,
        string memory ipfs
    ) public isValidDepositDate isNotPaused {
        uint256 totalAmount;
        for (uint256 i = 0; i < workers.length; ) {
            if (!isExistingWorker[workers[i]]) {
                isExistingWorker[workers[i]] = true;
                workerRetirementDate[workers[i]] = retirements[i];
            }
            totalAmount += amounts[i];
            unchecked {
                i++;
            }
        }
        amountThisIteration += totalAmount;

        USDC.transferFrom(msg.sender, address(this), totalAmount);
        emit ScheduleCreated(ipfs, msg.sender);
    }

    function withdrawUSDC() public onlyOperator {
        USDC.transferFrom(address(this), msg.sender, amountThisIteration);
        delete amountThisIteration;
    }

    function getWorkerRetirementDate(address worker)
        public
        view
        returns (uint256)
    {
        return workerRetirementDate[worker];
    }

    function changePause() public onlyAdmin {
        isPaused = !isPaused;
    }

    function _timestampToDate(uint256 timestamp)
        internal
        pure
        returns (uint256 day)
    {
        int256 X = int256(timestamp / (24 * 60 * 60));
        int256 L = X + 68569 + 2440588;
        int256 N = (4 * L) / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = (4000 * (L + 1)) / 1461001;
        L = L - (1461 * _year) / 4 + 31;
        int256 _month = (80 * L) / 2447;
        day = uint256(L - (2447 * _month) / 80);
    }
}
