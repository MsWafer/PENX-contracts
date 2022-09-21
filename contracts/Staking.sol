// SPDX-License-Identifier: MIT OR Apache-2.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IScheduler.sol";
import "./mixins/cryptography.sol";

contract Staking is SignatureControl {
    IERC20 PXLT;
    IERC20 PENX;
    IScheduler scheduler;
    bool isPaused = true;

    mapping(address => mapping(uint256 => bool)) usedNonces;

    mapping(address => uint256) public stakedPENX;
    uint256 public withdrawFee = 500;

    uint256 accumulatedSetFee;

    event Withdraw(
        address account,
        uint256 pxlt,
        uint256 PENX,
        bool hasFee
    );

    modifier isNotPaused() {
        require(!isPaused);
        _;
    }

    modifier isValidNonce(uint256 _nonce) {
        require(usedNonces[msg.sender][_nonce] != true, "Used nonce");
        _;
    }

    modifier isValidWithdraw(
        bytes memory signature,
        uint256 PXLTAmount,
        uint256 PENXAmount,
        uint256 nonce,
        uint256 timestamp
    ) {
        address signer = getSigner(
            signature,
            PXLTAmount,
            PENXAmount,
            nonce,
            timestamp
        );
        require(scheduler.isOperator(signer), "Mint not verified by operator");
        require(!usedNonces[msg.sender][nonce], "Used nonce");
        require(block.timestamp <= timestamp, "Outdated signed message");
        _;
    }

    constructor(
        IERC20 _PXLT,
        IERC20 _PENX,
        IScheduler _scheduler
    ) {
        PXLT = _PXLT;
        PENX = _PENX;
        scheduler = _scheduler;
    }

    function addSchedules(address[] memory workers, uint256[] memory amounts)
        public
    {
        require(scheduler.isOperator(msg.sender), "Caller is not an operator");
        require(workers.length == amounts.length, "Incorrect arrays provided");
        uint256 totalAmount;
        for (uint256 i = 0; i < workers.length; ) {
            stakedPENX[workers[i]] += amounts[i];
            totalAmount += amounts[i];
            unchecked {
                i++;
            }
        }
        PENX.transferFrom(msg.sender, address(this), totalAmount);
    }

    function withdrawPension(
        bytes memory signature,
        uint256 PXLTAmount,
        uint256 PENXAmount,
        uint256 nonce,
        uint256 timestamp
    )
        public
        isValidWithdraw(signature, PXLTAmount, PENXAmount, nonce, timestamp)
    {
        usedNonces[msg.sender][nonce] = true;
        bool hasFee;
        if (scheduler.getWorkerRetirementDate(msg.sender) < block.timestamp) {
            hasFee = true;
        }
        if (hasFee) {
            uint256 penXFee = (PXLTAmount / 10000) * withdrawFee;
            uint256 setFee = (PENXAmount / 10000) * withdrawFee;
            PENXAmount -= setFee;
            PXLTAmount -= penXFee;
            accumulatedSetFee += setFee;
        }

        PENX.transfer(address(this), stakedPENX[msg.sender]);
        PXLT.transfer(address(this), PXLTAmount);

        emit Withdraw(msg.sender, PXLTAmount, PENXAmount, hasFee);
    }

    function withdrawAccumulatedFee() public {
        require(scheduler.isAdmin(msg.sender), "Restricted method");
        PENX.transferFrom(address(this), msg.sender, accumulatedSetFee);
    }
}
