// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./access/Ownable.sol";

contract ComplianceRegistry is Ownable {
    error NotComplianceOfficer();

    mapping(address => bool) public complianceOfficer;
    mapping(address => bool) public isVerified;

    event ComplianceOfficerUpdated(address indexed officer, bool approved);
    event InvestorVerificationUpdated(address indexed investor, bool verified, string referenceId);

    constructor(address initialOwner) Ownable(initialOwner) {
        complianceOfficer[initialOwner] = true;
    }

    modifier onlyComplianceOfficer() {
        if (!complianceOfficer[msg.sender]) revert NotComplianceOfficer();
        _;
    }

    function setComplianceOfficer(address officer, bool approved) external onlyOwner {
        complianceOfficer[officer] = approved;
        emit ComplianceOfficerUpdated(officer, approved);
    }

    function setVerified(address investor, bool verified, string calldata referenceId) external onlyComplianceOfficer {
        isVerified[investor] = verified;
        emit InvestorVerificationUpdated(investor, verified, referenceId);
    }
}

