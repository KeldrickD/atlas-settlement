// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "./MockERC20.sol";

contract MockStablecoin is MockERC20 {
    constructor() MockERC20("Mock USDC", "mUSDC", 6) {}
}

