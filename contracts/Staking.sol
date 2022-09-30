// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IScheduler.sol";
import "./interfaces/ISwap.sol";

contract Staking {
    IERC20 PENX;
    IERC20 PXLT;
    IERC20 USDC;
    ISwap router;
    IScheduler scheduler;
    bool isPaused = true;

    // uint256 secondsInDay = 86400;
    uint256 secondsInDay = 60;

    uint256 public withdrawFee = 500;

    uint256 accumulatedSetFee;

    address[] workerArray;
    mapping(address => WorkerInfo) public workerAddressToInfo;
    struct WorkerInfo {
        uint256 stakedSet;
        uint256 accruedPENX;
        uint256 stakingStart;
    }

    uint256 coefficient = 11000;

    event Withdraw(
        address account,
        uint256 PENX,
        uint256 PXLT,
        uint256 swappedFor,
        bool hasFee
    );

    modifier isNotPaused() {
        require(!isPaused);
        _;
    }

    constructor(
        IERC20 _PENX,
        IERC20 _PXLT,
        IERC20 _USDC,
        IScheduler _scheduler,
        ISwap _router
    ) {
        PENX = _PENX;
        PXLT = _PXLT;
        USDC = _USDC;
        scheduler = _scheduler;
        router = _router;
    }

    function addWorker(address worker, uint256 setAmount)
        internal
        returns (bool isNew)
    {
        WorkerInfo storage info = workerAddressToInfo[worker];
        info.stakedSet += setAmount;
        if (info.stakingStart == 0) {
            info.stakingStart = block.timestamp;
            isNew = true;
        }
    }

    function addSchedules(address[] memory workers, uint256[] memory amounts)
        public
    {
        require(scheduler.isOperator(msg.sender), "Caller is not an operator");
        require(workers.length == amounts.length, "Incorrect arrays length");
        uint256 totalAmount;
        for (uint256 i = 0; i < workers.length; ) {
            if (addWorker(workers[i], amounts[i])) {
                workerArray.push(workers[i]);
            }
            totalAmount += amounts[i];
            unchecked {
                i++;
            }
        }
        PXLT.transferFrom(msg.sender, address(this), totalAmount);
    }

    function increaseStakes() public {
        require(scheduler.isOperator(msg.sender), "Caller is not an operator");
        for (uint256 i = 0; i < workerArray.length; ) {
            WorkerInfo storage info = workerAddressToInfo[workerArray[i]];
            if (
                info.stakedSet > 0 &&
                scheduler.getWorkerRetirementDate(workerArray[i]) >=
                block.timestamp
            ) {
                uint256 totalSupply = PXLT.totalSupply();
                updateWorkerStake(info, totalSupply);
            }
            unchecked {
                i++;
            }
        }
    }

    function updateWorkerStake(WorkerInfo storage info, uint256 totalSupply)
        internal
    {
        uint256 secondsPassed = block.timestamp - info.stakingStart;
        uint256 leftoverSeconds = secondsPassed % secondsInDay;
        uint256 daysPassedSinceDeposit = (secondsPassed - leftoverSeconds) /
            secondsInDay;
        uint256 PENXtoAdd = (((info.stakedSet * sqrt(daysPassedSinceDeposit)) /
            (totalSupply / 1e18)) * coefficient) / 10000;
        info.accruedPENX += PENXtoAdd;
    }

    function sqrt(uint256 x) internal pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function withdrawPension() public {
        WorkerInfo storage info = workerAddressToInfo[msg.sender];
        require(info.stakedSet > 0, "Nothing to collect");

        bool hasFee;
        if (scheduler.getWorkerRetirementDate(msg.sender) < block.timestamp) {
            hasFee = true;
        }

        if (hasFee) {
            uint256 setFee = (info.stakedSet / 10000) * withdrawFee;
            uint256 penxFee = (info.accruedPENX / 10000) * withdrawFee;
            info.stakedSet -= setFee;
            accumulatedSetFee += setFee;
            info.accruedPENX -= penxFee;
        }

        address[] memory path = new address[](2);
        path[0] = address(PXLT);
        path[1] = address(USDC);
        PXLT.approve(address(router), info.stakedSet);
        uint256[] memory amounts = router.swapExactTokensForTokens(
            info.stakedSet,
            1,
            path,
            msg.sender,
            block.timestamp
        );
        PENX.transfer(msg.sender, info.accruedPENX);
        emit Withdraw(
            msg.sender,
            info.accruedPENX,
            info.stakedSet,
            amounts[1],
            hasFee
        );
        delete workerAddressToInfo[msg.sender];
    }

    function withdrawAccumulatedFee() public {
        require(scheduler.isAdmin(msg.sender), "Restricted method");
        PXLT.transferFrom(address(this), msg.sender, accumulatedSetFee);
    }
}
