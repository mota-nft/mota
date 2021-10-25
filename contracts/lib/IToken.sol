// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IToken {
    function mint(address addr, uint256 amount) external;

    function approve(address spender, uint256 amount) external returns (bool);
}
