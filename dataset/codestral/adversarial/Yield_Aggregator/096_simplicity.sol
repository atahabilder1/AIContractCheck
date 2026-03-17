// SPDX-License-Identifier: MIT
   pragma solidity ^0.8.0;

   contract YieldAggregator {
       uint256 public totalYield;

       constructor() {
           totalYield = 0;
       }

       function addYield(uint256 _yield) external {
           totalYield += _yield;
       }
   }