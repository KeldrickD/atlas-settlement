// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AssetToken} from "../contracts/AssetToken.sol";
import {ComplianceRegistry} from "../contracts/ComplianceRegistry.sol";
import {DividendDistributor} from "../contracts/DividendDistributor.sol";
import {Ownable} from "../contracts/access/Ownable.sol";
import {ReentrancyGuard} from "../contracts/security/ReentrancyGuard.sol";
import {BaseERC20} from "../contracts/token/BaseERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../contracts/mocks/MockERC20.sol";
import {MockPriceFeed} from "../contracts/mocks/MockPriceFeed.sol";
import {OracleRiskModule} from "../contracts/OracleRiskModule.sol";
import {SettlementEscrow} from "../contracts/SettlementEscrow.sol";
import {SmartCustodyWallet} from "../contracts/SmartCustodyWallet.sol";

contract ReentrantPaymentToken is IERC20 {
    string public name = "Reentrant USD";
    string public symbol = "rUSD";
    uint8 public decimals = 6;
    uint256 public totalSupply;

    SettlementEscrow public escrow;
    uint256 public settlementId;
    bool public attackEnabled;
    bool public reentryBlocked;
    bytes4 public reentryError;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function configureAttack(SettlementEscrow escrow_, uint256 settlementId_) external {
        escrow = escrow_;
        settlementId = settlementId_;
        attackEnabled = true;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed < amount) revert BaseERC20.InsufficientAllowance();
        allowance[from][msg.sender] = allowed - amount;

        if (attackEnabled) {
            attackEnabled = false;
            try escrow.approveAndSettle(settlementId) {
                reentryBlocked = false;
            } catch (bytes memory reason) {
                reentryBlocked = true;
                if (reason.length >= 4) {
                    reentryError = bytes4(reason);
                }
            }
        }

        _transfer(from, to, amount);
        emit Approval(from, msg.sender, allowance[from][msg.sender]);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (balanceOf[from] < amount) revert BaseERC20.InsufficientBalance();
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract AtlasSettlementTest is Test {
    address internal issuer = address(0xA11CE);
    address internal seller = address(0xB0B);
    address internal buyer = address(0xCAFE);
    address internal outsider = address(0xBAD);
    address internal signer2 = address(0x2222);

    ComplianceRegistry internal registry;
    AssetToken internal asset;
    MockERC20 internal usd;
    MockPriceFeed internal feed;
    OracleRiskModule internal risk;
    SettlementEscrow internal escrow;
    DividendDistributor internal dividends;
    SmartCustodyWallet internal custody;

    function setUp() public {
        vm.warp(1_800_000_000);
        registry = new ComplianceRegistry(issuer);
        vm.startPrank(issuer);
        registry.setVerified(issuer, true, "ISSUER");
        registry.setVerified(seller, true, "KYC-SELLER");
        registry.setVerified(buyer, true, "KYC-BUYER");
        vm.stopPrank();

        asset = new AssetToken("Atlas Treasury Fund", "ATF", issuer, registry);
        usd = new MockERC20("Mock USD", "mUSD", 6);
        feed = new MockPriceFeed();
        feed.setPrice(100_00000000, block.timestamp);
        risk = new OracleRiskModule(issuer, feed, 1 hours, 500);

        vm.prank(issuer);
        risk.setRiskParameters(1 hours, 500, 100_00000000);

        escrow = new SettlementEscrow(issuer, IERC20(address(usd)), asset, registry, risk);
        dividends = new DividendDistributor(issuer, asset, IERC20(address(usd)), registry);
        custody = new SmartCustodyWallet(issuer, 10_000e6, 2);

        vm.startPrank(issuer);
        registry.setVerified(address(escrow), true, "APPROVED-ESCROW");
        dividends.setAssetHolder(seller, true);
        dividends.setAssetHolder(buyer, true);
        custody.setOperator(seller, true);
        custody.setSigner(signer2, true);
        asset.issue(seller, 1_000e18, "UST-2026-A");
        vm.stopPrank();

        usd.mint(buyer, 1_000_000e6);
        usd.mint(issuer, 1_000_000e6);
        usd.mint(address(custody), 100_000e6);
    }

    function testIssueAsset() public {
        assertEq(asset.balanceOf(seller), 1_000e18);
        assertEq(asset.totalSupply(), 1_000e18);
    }

    function testOnlyWhitelistedInvestorCanReceive() public {
        vm.prank(seller);
        vm.expectRevert(abi.encodeWithSelector(AssetToken.InvestorNotVerified.selector, outsider));
        asset.transfer(outsider, 1e18);
    }

    function testSettlementTransfersAssetAndPayment() public {
        uint256 settlementId = _createSettlement(100e18, 10_000e6);

        vm.prank(buyer);
        usd.approve(address(escrow), 10_000e6);
        vm.prank(buyer);
        escrow.approveAndSettle(settlementId);

        assertEq(asset.balanceOf(buyer), 100e18);
        assertEq(usd.balanceOf(seller), 10_000e6);
        (, , , , SettlementEscrow.Status status,) = escrow.settlements(settlementId);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.SETTLED));
    }

    function testSettlementFailsIfSellerHasNotApprovedAsset() public {
        vm.prank(seller);
        vm.expectRevert(BaseERC20.InsufficientAllowance.selector);
        escrow.createSettlement(buyer, 100e18, 10_000e6, "NO-SELLER-APPROVAL");
    }

    function testSettlementFailsIfBuyerHasNotApprovedPayment() public {
        uint256 settlementId = _createSettlement(100e18, 10_000e6);

        vm.prank(buyer);
        vm.expectRevert(BaseERC20.InsufficientAllowance.selector);
        escrow.approveAndSettle(settlementId);

        (, , , , SettlementEscrow.Status status,) = escrow.settlements(settlementId);
        assertEq(uint256(status), uint256(SettlementEscrow.Status.FUNDED));
    }

    function testRevertsWhenOracleIsStale() public {
        uint256 settlementId = _createSettlement(100e18, 10_000e6);
        feed.setPrice(100_00000000, block.timestamp - 2 hours);

        vm.prank(buyer);
        usd.approve(address(escrow), 10_000e6);
        vm.prank(buyer);
        vm.expectRevert(OracleRiskModule.StaleOraclePrice.selector);
        escrow.approveAndSettle(settlementId);
    }

    function testRevertsOnUnauthorizedTransfer() public {
        vm.prank(outsider);
        vm.expectRevert(abi.encodeWithSelector(AssetToken.InvestorNotVerified.selector, outsider));
        asset.transfer(buyer, 1e18);
    }

    function testPauseBlocksSettlement() public {
        vm.prank(issuer);
        escrow.pause();

        vm.prank(seller);
        asset.approve(address(escrow), 10e18);
        vm.prank(seller);
        vm.expectRevert();
        escrow.createSettlement(buyer, 10e18, 1_000e6, "PAUSED");
    }

    function testUnauthorizedUsersCannotPauseOrChangeRoles() public {
        vm.prank(outsider);
        vm.expectRevert(Ownable.NotOwner.selector);
        escrow.pause();

        vm.prank(outsider);
        vm.expectRevert(Ownable.NotOwner.selector);
        asset.setMinter(outsider, true);

        vm.prank(outsider);
        vm.expectRevert(Ownable.NotOwner.selector);
        registry.setComplianceOfficer(outsider, true);

        vm.prank(outsider);
        vm.expectRevert(Ownable.NotOwner.selector);
        custody.setSigner(outsider, true);

        assertFalse(asset.minter(outsider));
        assertFalse(registry.complianceOfficer(outsider));
        assertFalse(custody.signer(outsider));
    }

    function testDividendDistribution() public {
        vm.startPrank(issuer);
        usd.approve(address(dividends), 100_000e6);
        dividends.fundDividend(100_000e6);
        vm.stopPrank();

        assertEq(dividends.claimable(seller), 100_000e6);
        vm.prank(seller);
        dividends.claim();
        assertEq(usd.balanceOf(seller), 100_000e6);
    }

    function testInvestorReceivingTokensAfterDistributionCannotClaimPreviousDistribution() public {
        vm.startPrank(issuer);
        usd.approve(address(dividends), 100_000e6);
        dividends.fundDividend(100_000e6);
        vm.stopPrank();

        vm.prank(seller);
        asset.transfer(buyer, 100e18);

        assertEq(asset.balanceOf(buyer), 100e18);
        assertEq(dividends.claimable(1, buyer), 0);
        assertEq(dividends.claimable(buyer), 0);

        vm.prank(buyer);
        vm.expectRevert(DividendDistributor.NothingToClaim.selector);
        dividends.claim(1);
    }

    function testInvestorWhoHeldTokensAtFundingClaimsCorrectDistributionAmount() public {
        vm.prank(seller);
        asset.transfer(buyer, 250e18);

        vm.startPrank(issuer);
        usd.approve(address(dividends), 100_000e6);
        dividends.fundDividend(100_000e6);
        vm.stopPrank();

        assertEq(dividends.claimable(1, seller), 75_000e6);
        assertEq(dividends.claimable(1, buyer), 25_000e6);

        vm.prank(buyer);
        dividends.claim(1);
        assertEq(usd.balanceOf(buyer), 1_025_000e6);

        vm.prank(seller);
        dividends.claim(1);
        assertEq(usd.balanceOf(seller), 75_000e6);
    }

    function testDoubleDividendClaimIsRejected() public {
        vm.startPrank(issuer);
        usd.approve(address(dividends), 100_000e6);
        dividends.fundDividend(100_000e6);
        vm.stopPrank();

        vm.prank(seller);
        dividends.claim(1);

        vm.prank(seller);
        vm.expectRevert(DividendDistributor.NothingToClaim.selector);
        dividends.claim(1);
    }

    function testCustodyWalletDailyLimitAndLargeTransferApproval() public {
        vm.prank(seller);
        custody.transferWithinLimit(IERC20(address(usd)), buyer, 1_000e6);
        assertEq(usd.balanceOf(buyer), 1_001_000e6);

        vm.prank(seller);
        uint256 transferId = custody.requestLargeTransfer(IERC20(address(usd)), buyer, 25_000e6);

        vm.prank(issuer);
        custody.approveLargeTransfer(transferId);
        assertEq(usd.balanceOf(buyer), 1_001_000e6);

        vm.prank(signer2);
        custody.approveLargeTransfer(transferId);
        assertEq(usd.balanceOf(buyer), 1_026_000e6);
    }

    function testReentrancyAttemptFailsDuringSettlementPaymentTransfer() public {
        ReentrantPaymentToken maliciousUsd = new ReentrantPaymentToken();
        SettlementEscrow guardedEscrow = new SettlementEscrow(issuer, maliciousUsd, asset, registry, risk);

        vm.prank(issuer);
        registry.setVerified(address(guardedEscrow), true, "REENTRANCY-ESCROW");

        vm.prank(seller);
        asset.approve(address(guardedEscrow), 25e18);
        vm.prank(seller);
        uint256 settlementId = guardedEscrow.createSettlement(buyer, 25e18, 2_500e6, "REENTRANCY");

        maliciousUsd.mint(buyer, 2_500e6);
        maliciousUsd.configureAttack(guardedEscrow, settlementId);

        vm.prank(buyer);
        maliciousUsd.approve(address(guardedEscrow), 2_500e6);
        vm.prank(buyer);
        guardedEscrow.approveAndSettle(settlementId);

        assertTrue(maliciousUsd.reentryBlocked());
        assertEq(maliciousUsd.reentryError(), ReentrancyGuard.ReentrantCall.selector);
        assertEq(asset.balanceOf(buyer), 25e18);
        assertEq(maliciousUsd.balanceOf(seller), 2_500e6);
    }

    function testFuzzSettlementAmounts(uint96 assetAmountRaw, uint96 paymentAmountRaw) public {
        uint256 assetAmount = bound(uint256(assetAmountRaw), 1e18, 500e18);
        uint256 paymentAmount = bound(uint256(paymentAmountRaw), 1e6, 500_000e6);

        uint256 settlementId = _createSettlement(assetAmount, paymentAmount);

        vm.prank(buyer);
        usd.approve(address(escrow), paymentAmount);
        vm.prank(buyer);
        escrow.approveAndSettle(settlementId);

        assertEq(asset.balanceOf(buyer), assetAmount);
        assertEq(usd.balanceOf(seller), paymentAmount);
    }

    function testFuzzOraclePriceBounds(uint64 rawPrice) public {
        uint256 boundedPrice = bound(uint256(rawPrice), 95_00000000, 105_00000000);
        feed.setPrice(int256(boundedPrice), block.timestamp);
        (int256 price,) = risk.checkRisk();
        assertEq(uint256(price), boundedPrice);
    }

    function testRevertsWhenOracleBreachesCircuitBreaker() public {
        uint256 settlementId = _createSettlement(100e18, 10_000e6);
        feed.setPrice(120_00000000, block.timestamp);

        vm.prank(buyer);
        usd.approve(address(escrow), 10_000e6);
        vm.prank(buyer);
        vm.expectRevert(OracleRiskModule.PriceOutsideCircuitBreaker.selector);
        escrow.approveAndSettle(settlementId);
    }

    function _createSettlement(uint256 assetAmount, uint256 paymentAmount) internal returns (uint256 settlementId) {
        vm.prank(seller);
        asset.approve(address(escrow), assetAmount);
        vm.prank(seller);
        settlementId = escrow.createSettlement(buyer, assetAmount, paymentAmount, "DVP-001");
    }
}
