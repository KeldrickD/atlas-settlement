// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseERC20} from "./token/BaseERC20.sol";
import {Ownable} from "./access/Ownable.sol";
import {Pausable} from "./security/Pausable.sol";
import {ComplianceRegistry} from "./ComplianceRegistry.sol";

contract AssetToken is BaseERC20, Ownable, Pausable {
    error NotMinter();
    error InvestorNotVerified(address investor);

    ComplianceRegistry public immutable registry;
    mapping(address => bool) public minter;

    event MinterUpdated(address indexed account, bool approved);
    event AssetIssued(address indexed to, uint256 amount, string instrumentId);

    constructor(
        string memory name_,
        string memory symbol_,
        address initialOwner,
        ComplianceRegistry registry_
    ) BaseERC20(name_, symbol_, 18) Ownable(initialOwner) {
        registry = registry_;
        minter[initialOwner] = true;
    }

    modifier onlyMinter() {
        if (!minter[msg.sender]) revert NotMinter();
        _;
    }

    function setMinter(address account, bool approved) external onlyOwner {
        minter[account] = approved;
        emit MinterUpdated(account, approved);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function issue(address to, uint256 amount, string calldata instrumentId) external onlyMinter whenNotPaused {
        _requireVerified(to);
        _mint(to, amount);
        emit AssetIssued(to, amount, instrumentId);
    }

    function transfer(address to, uint256 amount) public override whenNotPaused returns (bool) {
        _requireVerified(msg.sender);
        _requireVerified(to);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override whenNotPaused returns (bool) {
        _requireVerified(from);
        _requireVerified(to);
        return super.transferFrom(from, to, amount);
    }

    function _requireVerified(address investor) internal view {
        if (!registry.isVerified(investor)) revert InvestorNotVerified(investor);
    }
}

