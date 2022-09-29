// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IScheduler.sol";
import "./mixins/cryptography.sol";
import "./interfaces/ISwap.sol";

contract Staking is SignatureControl {
    IERC20 PENX;
    IERC20 PXLT;
    IERC20 USDC;
    ISwap router;
    IScheduler scheduler;
    bool isPaused = true;

    uint256 secondsInDay = 86400;

    // mapping(address => mapping(uint256 => bool)) usedNonces;

    // mapping(address => uint256) public stakedSet;
    // mapping(address => uint256) public penxAccrued;
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

    // modifier isValidNonce(uint256 _nonce) {
    //     require(usedNonces[msg.sender][_nonce] != true, "Used nonce");
    //     _;
    // }

    // modifier isValidWithdraw(
    //     bytes memory signature,
    //     uint256 PENXAmount,
    //     uint256 PXLTAmount,
    //     uint256 nonce,
    //     uint256 timestamp
    // ) {
    //     address signer = getSigner(
    //         signature,
    //         PENXAmount,
    //         PXLTAmount,
    //         nonce,
    //         timestamp
    //     );
    //     require(scheduler.isOperator(signer), "Mint not verified by operator");
    //     require(!usedNonces[msg.sender][nonce], "Used nonce");
    //     require(block.timestamp <= timestamp, "Outdated signed message");
    //     _;
    // }

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

    // function addSchedules(address[] memory workers, uint256[] memory amounts)
    //     public
    // {
    //     require(scheduler.isOperator(msg.sender), "Caller is not an operator");
    //     require(workers.length == amounts.length, "Incorrect arrays provided");
    //     uint256 totalAmount;
    //     for (uint256 i = 0; i < workers.length; ) {
    //         stakedSet[workers[i]] += amounts[i];
    //         totalAmount += amounts[i];
    //         unchecked {
    //             i++;
    //         }
    //     }
    //     PXLT.transferFrom(msg.sender, address(this), totalAmount);
    // }

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
            totalSupply) * coefficient) / 10000;
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
        uint256[] memory amounts = router.swapExactTokensForTokens(
            info.stakedSet,
            1,
            path,
            msg.sender,
            block.timestamp
        );
        PENX.transfer(address(this), info.accruedPENX);
        emit Withdraw(
            msg.sender,
            info.accruedPENX,
            info.stakedSet,
            amounts[1],
            hasFee
        );
        delete workerAddressToInfo[msg.sender];
    }

    // function withdrawPension(
    //     bytes memory signature,
    //     uint256 PENXAmount,
    //     uint256 PXLTAmount,
    //     uint256 nonce,
    //     uint256 timestamp
    // )
    //     public
    //     isValidWithdraw(signature, PENXAmount, PXLTAmount, nonce, timestamp)
    // {
    //     usedNonces[msg.sender][nonce] = true;
    //     bool hasFee;
    //     if (scheduler.getWorkerRetirementDate(msg.sender) < block.timestamp) {
    //         hasFee = true;
    //     }
    //     if (hasFee) {
    //         uint256 setFee = (PXLTAmount / 10000) * withdrawFee;
    //         uint256 penxFee = (PENXAmount / 10000) * withdrawFee;
    //         stakedSet[msg.sender] -= setFee;
    //         PENXAmount -= penxFee;
    //         accumulatedSetFee += setFee;
    //     }
    //     address[] memory path = new address[](2);
    //     path[0] = address(PXLT);
    //     path[1] = address(USDC);
    //     uint256[] memory amounts = router.swapExactTokensForTokens(
    //         stakedSet[msg.sender],
    //         1,
    //         path,
    //         msg.sender,
    //         block.timestamp
    //     );
    //     PENX.transfer(address(this), PENXAmount);

    //     emit Withdraw(msg.sender, PENXAmount, PXLTAmount, amounts[1], hasFee);
    // }

    function withdrawAccumulatedFee() public {
        require(scheduler.isAdmin(msg.sender), "Restricted method");
        PXLT.transferFrom(address(this), msg.sender, accumulatedSetFee);
    }
}
