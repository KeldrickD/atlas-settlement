// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseERC20} from "../token/BaseERC20.sol";

contract MockERC20 is BaseERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) BaseERC20(name_, symbol_, decimals_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

