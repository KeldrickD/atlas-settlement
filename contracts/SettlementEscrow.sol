// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "./access/Ownable.sol";
import {Pausable} from "./security/Pausable.sol";
import {ReentrancyGuard} from "./security/ReentrancyGuard.sol";
import {AssetToken} from "./AssetToken.sol";
import {ComplianceRegistry} from "./ComplianceRegistry.sol";
import {OracleRiskModule} from "./OracleRiskModule.sol";

contract SettlementEscrow is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status {
        NONE,
        FUNDED,
        SETTLED,
        CANCELLED
    }

    struct Settlement {
        address seller;
        address buyer;
        uint256 assetAmount;
        uint256 paymentAmount;
        Status status;
        string tradeRef;
    }

    error NotParty();
    error InvalidSettlement();
    error InvestorNotVerified(address investor);

    IERC20 public immutable paymentToken;
    AssetToken public immutable assetToken;
    ComplianceRegistry public immutable registry;
    OracleRiskModule public riskModule;

    uint256 public nextSettlementId = 1;
    mapping(uint256 => Settlement) public settlements;

    event SettlementCreated(
        uint256 indexed settlementId,
        address indexed seller,
        address indexed buyer,
        uint256 assetAmount,
        uint256 paymentAmount,
        string tradeRef
    );
    event SettlementSettled(uint256 indexed settlementId, int256 oraclePrice, uint256 oracleUpdatedAt);
    event SettlementCancelled(uint256 indexed settlementId);
    event RiskModuleUpdated(address indexed riskModule);

    constructor(
        address initialOwner,
        IERC20 paymentToken_,
        AssetToken assetToken_,
        ComplianceRegistry registry_,
        OracleRiskModule riskModule_
    ) Ownable(initialOwner) {
        paymentToken = paymentToken_;
        assetToken = assetToken_;
        registry = registry_;
        riskModule = riskModule_;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setRiskModule(OracleRiskModule riskModule_) external onlyOwner {
        riskModule = riskModule_;
        emit RiskModuleUpdated(address(riskModule_));
    }

    function createSettlement(address buyer, uint256 assetAmount, uint256 paymentAmount, string calldata tradeRef)
        external
        whenNotPaused
        nonReentrant
        returns (uint256 settlementId)
    {
        _requireVerified(msg.sender);
        _requireVerified(buyer);
        settlementId = nextSettlementId++;
        settlements[settlementId] = Settlement({
            seller: msg.sender,
            buyer: buyer,
            assetAmount: assetAmount,
            paymentAmount: paymentAmount,
            status: Status.FUNDED,
            tradeRef: tradeRef
        });

        IERC20(address(assetToken)).safeTransferFrom(msg.sender, address(this), assetAmount);
        emit SettlementCreated(settlementId, msg.sender, buyer, assetAmount, paymentAmount, tradeRef);
    }

    function approveAndSettle(uint256 settlementId) external whenNotPaused nonReentrant {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.status != Status.FUNDED) revert InvalidSettlement();
        if (msg.sender != settlement.buyer) revert NotParty();

        (int256 price, uint256 updatedAt) = riskModule.checkRisk();
        settlement.status = Status.SETTLED;

        paymentToken.safeTransferFrom(settlement.buyer, settlement.seller, settlement.paymentAmount);
        IERC20(address(assetToken)).safeTransfer(settlement.buyer, settlement.assetAmount);
        emit SettlementSettled(settlementId, price, updatedAt);
    }

    function cancel(uint256 settlementId) external whenNotPaused nonReentrant {
        Settlement storage settlement = settlements[settlementId];
        if (settlement.status != Status.FUNDED) revert InvalidSettlement();
        if (msg.sender != settlement.seller && msg.sender != owner) revert NotParty();
        settlement.status = Status.CANCELLED;
        IERC20(address(assetToken)).safeTransfer(settlement.seller, settlement.assetAmount);
        emit SettlementCancelled(settlementId);
    }

    function _requireVerified(address investor) internal view {
        if (!registry.isVerified(investor)) revert InvestorNotVerified(investor);
    }
}
