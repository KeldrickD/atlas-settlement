// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "./access/Ownable.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

contract OracleRiskModule is Ownable {
    error InvalidOraclePrice();
    error StaleOraclePrice();
    error PriceOutsideCircuitBreaker();

    IPriceFeed public priceFeed;
    uint256 public maxStaleness;
    uint256 public maxDeviationBps;
    int256 public referencePrice;

    event RiskParametersUpdated(uint256 maxStaleness, uint256 maxDeviationBps, int256 referencePrice);
    event PriceFeedUpdated(address indexed priceFeed);

    constructor(address initialOwner, IPriceFeed priceFeed_, uint256 maxStaleness_, uint256 maxDeviationBps_)
        Ownable(initialOwner)
    {
        priceFeed = priceFeed_;
        maxStaleness = maxStaleness_;
        maxDeviationBps = maxDeviationBps_;
    }

    function setPriceFeed(IPriceFeed priceFeed_) external onlyOwner {
        priceFeed = priceFeed_;
        emit PriceFeedUpdated(address(priceFeed_));
    }

    function setRiskParameters(uint256 maxStaleness_, uint256 maxDeviationBps_, int256 referencePrice_)
        external
        onlyOwner
    {
        maxStaleness = maxStaleness_;
        maxDeviationBps = maxDeviationBps_;
        referencePrice = referencePrice_;
        emit RiskParametersUpdated(maxStaleness_, maxDeviationBps_, referencePrice_);
    }

    function checkRisk() public view returns (int256 price, uint256 updatedAt) {
        (, price,, updatedAt,) = priceFeed.latestRoundData();
        if (price <= 0) revert InvalidOraclePrice();
        if (block.timestamp - updatedAt > maxStaleness) revert StaleOraclePrice();

        if (referencePrice > 0) {
            uint256 delta = price > referencePrice ? uint256(price - referencePrice) : uint256(referencePrice - price);
            uint256 deviationBps = (delta * 10_000) / uint256(referencePrice);
            if (deviationBps > maxDeviationBps) revert PriceOutsideCircuitBreaker();
        }
    }
}

