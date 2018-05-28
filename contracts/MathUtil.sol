pragma solidity ^0.4.23;


library MathUtil {
  function ceilLog2(uint _x) pure internal returns(uint) {
    require(_x > 0);

    uint x = _x;
    uint y = (((x & (x - 1)) == 0) ? 0 : 1);
    uint j = 128;
    uint k = 0;

    k = (((x & 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0xFFFFFFFFFFFFFFFF0000000000000000) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0xFFFFFFFF00000000) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0xFFFF0000) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0xFF00) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0xF0) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0xC) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    k = (((x & 0x2) == 0) ? 0 : j);
    y += k;
    x >>= k;
    j >>= 1;

    return y;
  }
}
