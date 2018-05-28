pragma solidity ^0.4.23;

import "../../contracts/MathUtil.sol";


contract MathUtilTest {
  function ceilLog2(uint _x) public pure returns (uint) {
    return MathUtil.ceilLog2(_x);
  }
}
