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
    IGeneratedTickMathInner[] memory _g
  ) public {
    g0 = _g[0];
    g1 = _g[1];
    g2 = _g[2];
    g3 = _g[3];
    g4 = _g[4];
    g5 = _g[5];
    g6 = _g[6];
    g7 = _g[7];
    g8 = _g[8];
    g9 = _g[9];
    g10 = _g[10];
    g11 = _g[11];
    g12 = _g[12];
    g13 = _g[13];
    g14 = _g[14];
    g15 = _g[15];
    g16 = _g[16];
    g17 = _g[17];
    g18 = _g[18];
    g19 = _g[19];
    g20 = _g[20];
    g21 = _g[21];
    g22 = _g[22];
    g23 = _g[23];
    g24 = _g[24];
    g25 = _g[25];
    g26 = _g[26];
    g27 = _g[27];
    g28 = _g[28];
    g29 = _g[29];
    g30 = _g[30];
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
  }
}
