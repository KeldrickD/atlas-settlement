// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "./access/Ownable.sol";
import {ReentrancyGuard} from "./security/ReentrancyGuard.sol";
import {AssetToken} from "./AssetToken.sol";
import {ComplianceRegistry} from "./ComplianceRegistry.sol";

contract DividendDistributor is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error NotVerified();
    error NothingToClaim();
    error InvalidAssetHolder();
    error AssetHolderNotVerified();
    error NoTokenSupply();

    struct Distribution {
        uint256 amount;
        uint256 totalSupplySnapshot;
        uint256 fundedAt;
    }

    AssetToken public immutable assetToken;
    IERC20 public immutable paymentToken;
    ComplianceRegistry public immutable registry;

    address[] private assetHolders;
    mapping(address => bool) public isAssetHolder;
    mapping(uint256 => Distribution) public distributions;
    mapping(uint256 => mapping(address => uint256)) public balanceSnapshot;
    mapping(uint256 => mapping(address => bool)) public claimed;
    uint256 public distributionCount;

    event AssetHolderUpdated(address indexed holder, bool approved);
    event DividendFunded(uint256 indexed distributionId, address indexed funder, uint256 amount, uint256 totalSupplySnapshot);
    event DividendClaimed(uint256 indexed distributionId, address indexed investor, uint256 amount);

    constructor(address initialOwner, AssetToken assetToken_, IERC20 paymentToken_, ComplianceRegistry registry_)
        Ownable(initialOwner)
    {
        assetToken = assetToken_;
        paymentToken = paymentToken_;
        registry = registry_;
    }

    function setAssetHolder(address holder, bool approved) external onlyOwner {
        if (holder == address(0)) revert InvalidAssetHolder();
        if (approved && !registry.isVerified(holder)) revert AssetHolderNotVerified();

        if (approved && !isAssetHolder[holder]) {
            assetHolders.push(holder);
        }

        isAssetHolder[holder] = approved;
        emit AssetHolderUpdated(holder, approved);
    }

    function fundDividend(uint256 amount) external onlyOwner nonReentrant {
        uint256 totalSupplySnapshot = assetToken.totalSupply();
        if (totalSupplySnapshot == 0) revert NoTokenSupply();

        uint256 distributionId = ++distributionCount;
        distributions[distributionId] = Distribution({
            amount: amount,
            totalSupplySnapshot: totalSupplySnapshot,
            fundedAt: block.timestamp
        });

        uint256 holderLength = assetHolders.length;
        for (uint256 i = 0; i < holderLength; i++) {
            address holder = assetHolders[i];
            if (isAssetHolder[holder] && registry.isVerified(holder)) {
                balanceSnapshot[distributionId][holder] = assetToken.balanceOf(holder);
            }
        }

        paymentToken.safeTransferFrom(msg.sender, address(this), amount);
        emit DividendFunded(distributionId, msg.sender, amount, totalSupplySnapshot);
    }

    function claim() external nonReentrant {
        if (!registry.isVerified(msg.sender)) revert NotVerified();
        uint256 totalAmount;

        for (uint256 distributionId = 1; distributionId <= distributionCount; distributionId++) {
            uint256 amount = _claimable(distributionId, msg.sender);
            if (amount > 0) {
                claimed[distributionId][msg.sender] = true;
                totalAmount += amount;
                emit DividendClaimed(distributionId, msg.sender, amount);
            }
        }

        if (totalAmount == 0) revert NothingToClaim();
        paymentToken.safeTransfer(msg.sender, totalAmount);
    }

    function claim(uint256 distributionId) external nonReentrant {
        if (!registry.isVerified(msg.sender)) revert NotVerified();
        uint256 amount = _claimable(distributionId, msg.sender);
        if (amount == 0) revert NothingToClaim();
        claimed[distributionId][msg.sender] = true;
        paymentToken.safeTransfer(msg.sender, amount);
        emit DividendClaimed(distributionId, msg.sender, amount);
    }

    function claimable(address investor) public view returns (uint256) {
        uint256 totalAmount;
        for (uint256 distributionId = 1; distributionId <= distributionCount; distributionId++) {
            totalAmount += _claimable(distributionId, investor);
        }
        return totalAmount;
    }

    function claimable(uint256 distributionId, address investor) public view returns (uint256) {
        return _claimable(distributionId, investor);
    }

    function assetHolderCount() external view returns (uint256) {
        return assetHolders.length;
    }

    function assetHolderAt(uint256 index) external view returns (address) {
        return assetHolders[index];
    }

    function _claimable(uint256 distributionId, address investor) internal view returns (uint256) {
        Distribution memory distribution = distributions[distributionId];
        if (claimed[distributionId][investor] || distribution.totalSupplySnapshot == 0) {
            return 0;
        }

        uint256 investorBalanceSnapshot = balanceSnapshot[distributionId][investor];
        if (investorBalanceSnapshot == 0) {
            return 0;
        }

        return (distribution.amount * investorBalanceSnapshot) / distribution.totalSupplySnapshot;
    }
}
