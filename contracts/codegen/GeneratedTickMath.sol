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
  IGeneratedTickMathInner immutable private g16;
  IGeneratedTickMathInner immutable private g17;
  IGeneratedTickMathInner immutable private g18;
  IGeneratedTickMathInner immutable private g19;
  IGeneratedTickMathInner immutable private g20;
  IGeneratedTickMathInner immutable private g21;
  IGeneratedTickMathInner immutable private g22;
  IGeneratedTickMathInner immutable private g23;
  IGeneratedTickMathInner immutable private g24;
  IGeneratedTickMathInner immutable private g25;
  IGeneratedTickMathInner immutable private g26;
  IGeneratedTickMathInner immutable private g27;
  IGeneratedTickMathInner immutable private g28;
  IGeneratedTickMathInner immutable private g29;
  IGeneratedTickMathInner immutable private g30;
  
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
    IGeneratedTickMathInner _g15,
    IGeneratedTickMathInner _g16,
    IGeneratedTickMathInner _g17,
    IGeneratedTickMathInner _g18,
    IGeneratedTickMathInner _g19,
    IGeneratedTickMathInner _g20,
    IGeneratedTickMathInner _g21,
    IGeneratedTickMathInner _g22,
    IGeneratedTickMathInner _g23,
    IGeneratedTickMathInner _g24,
    IGeneratedTickMathInner _g25,
    IGeneratedTickMathInner _g26,
    IGeneratedTickMathInner _g27,
    IGeneratedTickMathInner _g28,
    IGeneratedTickMathInner _g29,
    IGeneratedTickMathInner _g30
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
    g16 = _g16;
    g17 = _g17;
    g18 = _g18;
    g19 = _g19;
    g20 = _g20;
    g21 = _g21;
    g22 = _g22;
    g23 = _g23;
    g24 = _g24;
    g25 = _g25;
    g26 = _g26;
    g27 = _g27;
    g28 = _g28;
    g29 = _g29;
    g30 = _g30;
  }
  
  function getRatioAtTick(int256 tick) external view returns (uint256) {
    if (tick < -52) {
      if (tick < -4148) {
        if (tick < -6196) {
          if (tick < -7220) {
            return g0.getRatioAtTick(tick);
          } else {
            if (tick >= -6708) return g2.getRatioAtTick(tick); else return g1.getRatioAtTick(tick);
          }
        } else {
          if (tick < -5172) {
            if (tick >= -5684) return g4.getRatioAtTick(tick); else return g3.getRatioAtTick(tick);
          } else {
            if (tick >= -4660) return g6.getRatioAtTick(tick); else return g5.getRatioAtTick(tick);
          }
        }
      } else {
        if (tick < -2100) {
          if (tick < -3124) {
            if (tick >= -3636) return g8.getRatioAtTick(tick); else return g7.getRatioAtTick(tick);
          } else {
            if (tick >= -2612) return g10.getRatioAtTick(tick); else return g9.getRatioAtTick(tick);
          }
        } else {
          if (tick < -1076) {
            if (tick >= -1588) return g12.getRatioAtTick(tick); else return g11.getRatioAtTick(tick);
          } else {
            if (tick >= -564) return g14.getRatioAtTick(tick); else return g13.getRatioAtTick(tick);
          }
        }
      }
    } else {
      if (tick < 4044) {
        if (tick < 1996) {
          if (tick < 972) {
            if (tick >= 460) return g16.getRatioAtTick(tick); else return g15.getRatioAtTick(tick);
          } else {
            if (tick >= 1484) return g18.getRatioAtTick(tick); else return g17.getRatioAtTick(tick);
          }
        } else {
          if (tick < 3020) {
            if (tick >= 2508) return g20.getRatioAtTick(tick); else return g19.getRatioAtTick(tick);
          } else {
            if (tick >= 3532) return g22.getRatioAtTick(tick); else return g21.getRatioAtTick(tick);
          }
        }
      } else {
        if (tick < 6092) {
          if (tick < 5068) {
            if (tick >= 4556) return g24.getRatioAtTick(tick); else return g23.getRatioAtTick(tick);
          } else {
            if (tick >= 5580) return g26.getRatioAtTick(tick); else return g25.getRatioAtTick(tick);
          }
        } else {
          if (tick < 7116) {
            if (tick >= 6604) return g28.getRatioAtTick(tick); else return g27.getRatioAtTick(tick);
          } else {
            if (tick >= 7628) return g30.getRatioAtTick(tick); else return g29.getRatioAtTick(tick);
          }
        }
      }
    }
    revert('invalid tick');
  }
}
