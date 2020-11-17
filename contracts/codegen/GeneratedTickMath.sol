/////// This code is generated. Do not modify by hand.
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

interface IGeneratedTickMathInner {
  function getRatioAtTick(int256 tick) external pure returns (uint256);
}

contract GeneratedTickMath {
  IGeneratedTickMathInner immutable private g0;
  IGeneratedTickMathInner immutable private g1;
  IGeneratedTickMathInner immutable private g2;
  IGeneratedTickMathInner immutable private g3;
  IGeneratedTickMathInner immutable private g4;
  IGeneratedTickMathInner immutable private g5;
  IGeneratedTickMathInner immutable private g6;
  IGeneratedTickMathInner immutable private g7;
  IGeneratedTickMathInner immutable private g8;
  IGeneratedTickMathInner immutable private g9;
  IGeneratedTickMathInner immutable private g10;
  IGeneratedTickMathInner immutable private g11;
  IGeneratedTickMathInner immutable private g12;
  IGeneratedTickMathInner immutable private g13;
  IGeneratedTickMathInner immutable private g14;
  IGeneratedTickMathInner immutable private g15;
  
  constructor(
    IGeneratedTickMathInner _g0,
    IGeneratedTickMathInner _g1,
    IGeneratedTickMathInner _g2,
    IGeneratedTickMathInner _g3,
    IGeneratedTickMathInner _g4,
    IGeneratedTickMathInner _g5,
    IGeneratedTickMathInner _g6,
    IGeneratedTickMathInner _g7,
    IGeneratedTickMathInner _g8,
    IGeneratedTickMathInner _g9,
    IGeneratedTickMathInner _g10,
    IGeneratedTickMathInner _g11,
    IGeneratedTickMathInner _g12,
    IGeneratedTickMathInner _g13,
    IGeneratedTickMathInner _g14,
    IGeneratedTickMathInner _g15
  ) public {
    g0 = _g0;
    g1 = _g1;
    g2 = _g2;
    g3 = _g3;
    g4 = _g4;
    g5 = _g5;
    g6 = _g6;
    g7 = _g7;
    g8 = _g8;
    g9 = _g9;
    g10 = _g10;
    g11 = _g11;
    g12 = _g12;
    g13 = _g13;
    g14 = _g14;
    g15 = _g15;
  }
  
  function getRatioAtTick(int256 tick) external pure returns (uint256) {
    if (tick < 1267) {
      if (tick < -2733) {
        if (tick < -4733) {
          if (tick <= -6733) return g0.getRatioAtTick(tick); else return g1.getRatioAtTick(tick);
        } else {
          if (tick <= -4733) return g2.getRatioAtTick(tick); else return g3.getRatioAtTick(tick);
        }
      } else {
        if (tick < -733) {
          if (tick <= -2733) return g4.getRatioAtTick(tick); else return g5.getRatioAtTick(tick);
        } else {
          if (tick <= -733) return g6.getRatioAtTick(tick); else return g7.getRatioAtTick(tick);
        }
      }
    } else {
      if (tick < 5267) {
        if (tick < 3267) {
          if (tick <= 1267) return g8.getRatioAtTick(tick); else return g9.getRatioAtTick(tick);
        } else {
          if (tick <= 3267) return g10.getRatioAtTick(tick); else return g11.getRatioAtTick(tick);
        }
      } else {
        if (tick < 7267) {
          if (tick <= 5267) return g12.getRatioAtTick(tick); else return g13.getRatioAtTick(tick);
        } else {
          if (tick <= 7267) return g14.getRatioAtTick(tick); else return g15.getRatioAtTick(tick);
        }
      }
    }
    revert('invalid tick');
  }
}
