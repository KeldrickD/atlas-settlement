// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {AssetToken} from "../contracts/AssetToken.sol";
import {ComplianceRegistry} from "../contracts/ComplianceRegistry.sol";
import {DividendDistributor} from "../contracts/DividendDistributor.sol";
import {MockOracle} from "../contracts/mocks/MockOracle.sol";
import {MockStablecoin} from "../contracts/mocks/MockStablecoin.sol";
import {OracleRiskModule} from "../contracts/OracleRiskModule.sol";
import {SettlementEscrow} from "../contracts/SettlementEscrow.sol";
import {SmartCustodyWallet} from "../contracts/SmartCustodyWallet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployLocal is Script {
    uint256 private constant ISSUER_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private constant SELLER_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    address private constant ISSUER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address private constant SELLER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address private constant BUYER = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address private constant SIGNER = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function run() external {
        vm.startBroadcast(ISSUER_PRIVATE_KEY);

        ComplianceRegistry registry = new ComplianceRegistry(ISSUER);
        AssetToken asset = new AssetToken("Atlas Treasury Fund", "ATF", ISSUER, registry);
        MockStablecoin stablecoin = new MockStablecoin();
        MockOracle oracle = new MockOracle();
        oracle.setPrice(100_00000000, block.timestamp);
        OracleRiskModule riskModule = new OracleRiskModule(ISSUER, oracle, 1 hours, 500);
        riskModule.setRiskParameters(1 hours, 500, 100_00000000);

        SettlementEscrow escrow =
            new SettlementEscrow(ISSUER, IERC20(address(stablecoin)), asset, registry, riskModule);
        SmartCustodyWallet custody = new SmartCustodyWallet(ISSUER, 10_000e6, 2);
        DividendDistributor dividend =
            new DividendDistributor(ISSUER, asset, IERC20(address(stablecoin)), registry);

        registry.setVerified(ISSUER, true, "ANVIL-ISSUER");
        registry.setVerified(SELLER, true, "ANVIL-SELLER");
        registry.setVerified(BUYER, true, "ANVIL-BUYER");
        registry.setVerified(address(escrow), true, "ANVIL-ESCROW");
        registry.setVerified(address(custody), true, "ANVIL-CUSTODY");
        registry.setVerified(address(dividend), true, "ANVIL-DIVIDEND");

        custody.setOperator(SELLER, true);
        custody.setSigner(SIGNER, true);
        dividend.setAssetHolder(SELLER, true);
        dividend.setAssetHolder(BUYER, true);

        asset.issue(SELLER, 1_000_000e18, "ATF-ANVIL-001");
        stablecoin.mint(BUYER, 1_000_000e6);
        stablecoin.mint(ISSUER, 1_000_000e6);
        stablecoin.mint(address(custody), 100_000e6);

        vm.stopBroadcast();

        vm.startBroadcast(SELLER_PRIVATE_KEY);
        asset.approve(address(escrow), type(uint256).max);
        vm.stopBroadcast();

        string memory json = "deployment";
        vm.serializeString(json, "network", "anvil");
        vm.serializeUint(json, "chainId", 31337);
        vm.serializeAddress(json, "issuer", ISSUER);
        vm.serializeAddress(json, "seller", SELLER);
        vm.serializeAddress(json, "buyer", BUYER);
        vm.serializeAddress(json, "complianceRegistry", address(registry));
        vm.serializeAddress(json, "assetToken", address(asset));
        vm.serializeAddress(json, "mockStablecoin", address(stablecoin));
        vm.serializeAddress(json, "mockOracle", address(oracle));
        vm.serializeAddress(json, "oracleRiskModule", address(riskModule));
        vm.serializeAddress(json, "settlementEscrow", address(escrow));
        vm.serializeAddress(json, "smartCustodyWallet", address(custody));
        string memory finalJson = vm.serializeAddress(json, "dividendDistributor", address(dividend));
        vm.writeJson(finalJson, "deployments/anvil.json");
    }
}
