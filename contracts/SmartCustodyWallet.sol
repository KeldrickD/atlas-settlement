// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "./access/Ownable.sol";
import {Pausable} from "./security/Pausable.sol";
import {ReentrancyGuard} from "./security/ReentrancyGuard.sol";

contract SmartCustodyWallet is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct PendingTransfer {
        address token;
        address to;
        uint256 amount;
        uint256 approvals;
        bool executed;
    }

    error NotOperator();
    error NotSigner();
    error LimitExceeded();
    error AlreadyApproved();
    error InvalidTransfer();

    mapping(address => bool) public operator;
    mapping(address => bool) public signer;
    uint256 public signerCount;
    uint256 public approvalThreshold;
    uint256 public dailyLimit;
    uint256 public spentToday;
    uint256 public dayStart;
    uint256 public nextTransferId = 1;

    mapping(uint256 => PendingTransfer) public pendingTransfers;
    mapping(uint256 => mapping(address => bool)) public approvedBy;

    event OperatorUpdated(address indexed operator, bool approved);
    event SignerUpdated(address indexed signer, bool approved);
    event DailyLimitUpdated(uint256 dailyLimit);
    event TransferExecuted(address indexed token, address indexed to, uint256 amount);
    event LargeTransferRequested(uint256 indexed transferId, address indexed token, address indexed to, uint256 amount);
    event LargeTransferApproved(uint256 indexed transferId, address indexed signer);

    constructor(address initialOwner, uint256 dailyLimit_, uint256 approvalThreshold_) Ownable(initialOwner) {
        signer[initialOwner] = true;
        signerCount = 1;
        approvalThreshold = approvalThreshold_;
        dailyLimit = dailyLimit_;
        dayStart = block.timestamp;
    }

    modifier onlyOperator() {
        if (!operator[msg.sender] && msg.sender != owner) revert NotOperator();
        _;
    }

    modifier onlySigner() {
        if (!signer[msg.sender]) revert NotSigner();
        _;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setOperator(address account, bool approved) external onlyOwner {
        operator[account] = approved;
        emit OperatorUpdated(account, approved);
    }

    function setSigner(address account, bool approved) external onlyOwner {
        if (signer[account] == approved) return;
        signer[account] = approved;
        signerCount = approved ? signerCount + 1 : signerCount - 1;
        emit SignerUpdated(account, approved);
    }

    function setDailyLimit(uint256 dailyLimit_) external onlyOwner {
        dailyLimit = dailyLimit_;
        emit DailyLimitUpdated(dailyLimit_);
    }

    function transferWithinLimit(IERC20 token, address to, uint256 amount)
        external
        onlyOperator
        whenNotPaused
        nonReentrant
    {
        _resetWindowIfNeeded();
        if (spentToday + amount > dailyLimit) revert LimitExceeded();
        spentToday += amount;
        token.safeTransfer(to, amount);
        emit TransferExecuted(address(token), to, amount);
    }

    function requestLargeTransfer(IERC20 token, address to, uint256 amount)
        external
        onlyOperator
        whenNotPaused
        returns (uint256 transferId)
    {
        transferId = nextTransferId++;
        pendingTransfers[transferId] =
            PendingTransfer({token: address(token), to: to, amount: amount, approvals: 0, executed: false});
        emit LargeTransferRequested(transferId, address(token), to, amount);
    }

    function approveLargeTransfer(uint256 transferId) external onlySigner whenNotPaused nonReentrant {
        PendingTransfer storage pending = pendingTransfers[transferId];
        if (pending.token == address(0) || pending.executed) revert InvalidTransfer();
        if (approvedBy[transferId][msg.sender]) revert AlreadyApproved();

        approvedBy[transferId][msg.sender] = true;
        pending.approvals++;
        emit LargeTransferApproved(transferId, msg.sender);

        if (pending.approvals >= approvalThreshold) {
            pending.executed = true;
            IERC20(pending.token).safeTransfer(pending.to, pending.amount);
            emit TransferExecuted(pending.token, pending.to, pending.amount);
        }
    }

    function _resetWindowIfNeeded() internal {
        if (block.timestamp >= dayStart + 1 days) {
            dayStart = block.timestamp;
            spentToday = 0;
        }
    }
}
