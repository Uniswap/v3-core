/////// This code is generated. Do not modify by hand.
// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.5.0;

import '@uniswap/lib/contracts/libraries/FixedPoint.sol';

library GeneratedTickMath {
  function getRatioAtTick(int16 tick) internal pure returns (uint256) {
    require(tick >= -7732, 'GeneratedTickMath::getRatioAtTick: tick must be greater than -7732');
    require(tick <= 7732, 'GeneratedTickMath::getRatioAtTick: tick must be less than 7732');
    
   if (tick < -7182) {
     if (tick < -7457) {
       if (tick < -7595) {
         if (tick < -7664) {
           if (tick < -7698) {
             if (tick < -7715) {
               if (tick < -7724) {
                 if (tick < -7728) {
                   if (tick < -7730) {
                     if (tick == -7732) return 2; else return 2;
                   } else {
                     if (tick == -7730) return 2; else return 2;
                   }
                 } else {
                   if (tick < -7726) {
                     if (tick == -7728) return 2; else return 2;
                   } else {
                     if (tick == -7726) return 2; else return 2;
                   }
                 }
               } else {
                 if (tick < -7720) {
                   if (tick < -7722) {
                     if (tick == -7724) return 2; else return 2;
                   } else {
                     if (tick == -7722) return 2; else return 2;
                   }
                 } else {
                   if (tick < -7718) {
                     if (tick == -7720) return 2; else return 2;
                   } else {
                     if (tick < -7717) {
                       return 2;
                     } else {
                       if (tick == -7717) return 2; else return 2;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7707) {
                 if (tick < -7711) {
                   if (tick < -7713) {
                     if (tick == -7715) return 2; else return 2;
                   } else {
                     if (tick == -7713) return 2; else return 2;
                   }
                 } else {
                   if (tick < -7709) {
                     if (tick == -7711) return 2; else return 2;
                   } else {
                     if (tick == -7709) return 2; else return 2;
                   }
                 }
               } else {
                 if (tick < -7703) {
                   if (tick < -7705) {
                     if (tick == -7707) return 2; else return 2;
                   } else {
                     if (tick == -7705) return 2; else return 2;
                   }
                 } else {
                   if (tick < -7701) {
                     if (tick == -7703) return 2; else return 2;
                   } else {
                     if (tick < -7700) {
                       return 2;
                     } else {
                       if (tick == -7700) return 2; else return 2;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7681) {
               if (tick < -7690) {
                 if (tick < -7694) {
                   if (tick < -7696) {
                     if (tick == -7698) return 2; else return 2;
                   } else {
                     if (tick == -7696) return 2; else return 2;
                   }
                 } else {
                   if (tick < -7692) {
                     if (tick == -7694) return 2; else return 2;
                   } else {
                     if (tick == -7692) return 2; else return 3;
                   }
                 }
               } else {
                 if (tick < -7686) {
                   if (tick < -7688) {
                     if (tick == -7690) return 3; else return 3;
                   } else {
                     if (tick == -7688) return 3; else return 3;
                   }
                 } else {
                   if (tick < -7684) {
                     if (tick == -7686) return 3; else return 3;
                   } else {
                     if (tick < -7683) {
                       return 3;
                     } else {
                       if (tick == -7683) return 3; else return 3;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7673) {
                 if (tick < -7677) {
                   if (tick < -7679) {
                     if (tick == -7681) return 3; else return 3;
                   } else {
                     if (tick == -7679) return 3; else return 3;
                   }
                 } else {
                   if (tick < -7675) {
                     if (tick == -7677) return 3; else return 3;
                   } else {
                     if (tick == -7675) return 3; else return 3;
                   }
                 }
               } else {
                 if (tick < -7669) {
                   if (tick < -7671) {
                     if (tick == -7673) return 3; else return 3;
                   } else {
                     if (tick == -7671) return 3; else return 3;
                   }
                 } else {
                   if (tick < -7667) {
                     if (tick == -7669) return 3; else return 3;
                   } else {
                     if (tick < -7666) {
                       return 3;
                     } else {
                       if (tick == -7666) return 3; else return 3;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -7630) {
             if (tick < -7647) {
               if (tick < -7656) {
                 if (tick < -7660) {
                   if (tick < -7662) {
                     if (tick == -7664) return 3; else return 3;
                   } else {
                     if (tick == -7662) return 4; else return 4;
                   }
                 } else {
                   if (tick < -7658) {
                     if (tick == -7660) return 4; else return 4;
                   } else {
                     if (tick == -7658) return 4; else return 4;
                   }
                 }
               } else {
                 if (tick < -7652) {
                   if (tick < -7654) {
                     if (tick == -7656) return 4; else return 4;
                   } else {
                     if (tick == -7654) return 4; else return 4;
                   }
                 } else {
                   if (tick < -7650) {
                     if (tick == -7652) return 4; else return 4;
                   } else {
                     if (tick < -7649) {
                       return 4;
                     } else {
                       if (tick == -7649) return 4; else return 4;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7639) {
                 if (tick < -7643) {
                   if (tick < -7645) {
                     if (tick == -7647) return 4; else return 4;
                   } else {
                     if (tick == -7645) return 4; else return 4;
                   }
                 } else {
                   if (tick < -7641) {
                     if (tick == -7643) return 4; else return 4;
                   } else {
                     if (tick == -7641) return 4; else return 5;
                   }
                 }
               } else {
                 if (tick < -7635) {
                   if (tick < -7637) {
                     if (tick == -7639) return 5; else return 5;
                   } else {
                     if (tick == -7637) return 5; else return 5;
                   }
                 } else {
                   if (tick < -7633) {
                     if (tick == -7635) return 5; else return 5;
                   } else {
                     if (tick < -7632) {
                       return 5;
                     } else {
                       if (tick == -7632) return 5; else return 5;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7613) {
               if (tick < -7622) {
                 if (tick < -7626) {
                   if (tick < -7628) {
                     if (tick == -7630) return 5; else return 5;
                   } else {
                     if (tick == -7628) return 5; else return 5;
                   }
                 } else {
                   if (tick < -7624) {
                     if (tick == -7626) return 5; else return 5;
                   } else {
                     if (tick == -7624) return 5; else return 5;
                   }
                 }
               } else {
                 if (tick < -7618) {
                   if (tick < -7620) {
                     if (tick == -7622) return 5; else return 6;
                   } else {
                     if (tick == -7620) return 6; else return 6;
                   }
                 } else {
                   if (tick < -7616) {
                     if (tick == -7618) return 6; else return 6;
                   } else {
                     if (tick < -7615) {
                       return 6;
                     } else {
                       if (tick == -7615) return 6; else return 6;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7604) {
                 if (tick < -7609) {
                   if (tick < -7611) {
                     if (tick == -7613) return 6; else return 6;
                   } else {
                     if (tick == -7611) return 6; else return 6;
                   }
                 } else {
                   if (tick < -7607) {
                     if (tick == -7609) return 6; else return 6;
                   } else {
                     if (tick < -7606) {
                       return 6;
                     } else {
                       if (tick == -7606) return 7; else return 7;
                     }
                   }
                 }
               } else {
                 if (tick < -7600) {
                   if (tick < -7602) {
                     if (tick == -7604) return 7; else return 7;
                   } else {
                     if (tick == -7602) return 7; else return 7;
                   }
                 } else {
                   if (tick < -7598) {
                     if (tick == -7600) return 7; else return 7;
                   } else {
                     if (tick < -7597) {
                       return 7;
                     } else {
                       if (tick == -7597) return 7; else return 7;
                     }
                   }
                 }
               }
             }
           }
         }
       } else {
         if (tick < -7526) {
           if (tick < -7561) {
             if (tick < -7578) {
               if (tick < -7587) {
                 if (tick < -7591) {
                   if (tick < -7593) {
                     if (tick == -7595) return 7; else return 7;
                   } else {
                     if (tick == -7593) return 8; else return 8;
                   }
                 } else {
                   if (tick < -7589) {
                     if (tick == -7591) return 8; else return 8;
                   } else {
                     if (tick == -7589) return 8; else return 8;
                   }
                 }
               } else {
                 if (tick < -7583) {
                   if (tick < -7585) {
                     if (tick == -7587) return 8; else return 8;
                   } else {
                     if (tick == -7585) return 8; else return 8;
                   }
                 } else {
                   if (tick < -7581) {
                     if (tick == -7583) return 8; else return 8;
                   } else {
                     if (tick < -7580) {
                       return 9;
                     } else {
                       if (tick == -7580) return 9; else return 9;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7570) {
                 if (tick < -7574) {
                   if (tick < -7576) {
                     if (tick == -7578) return 9; else return 9;
                   } else {
                     if (tick == -7576) return 9; else return 9;
                   }
                 } else {
                   if (tick < -7572) {
                     if (tick == -7574) return 9; else return 9;
                   } else {
                     if (tick == -7572) return 9; else return 9;
                   }
                 }
               } else {
                 if (tick < -7566) {
                   if (tick < -7568) {
                     if (tick == -7570) return 10; else return 10;
                   } else {
                     if (tick == -7568) return 10; else return 10;
                   }
                 } else {
                   if (tick < -7564) {
                     if (tick == -7566) return 10; else return 10;
                   } else {
                     if (tick < -7563) {
                       return 10;
                     } else {
                       if (tick == -7563) return 10; else return 10;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7544) {
               if (tick < -7553) {
                 if (tick < -7557) {
                   if (tick < -7559) {
                     if (tick == -7561) return 11; else return 11;
                   } else {
                     if (tick == -7559) return 11; else return 11;
                   }
                 } else {
                   if (tick < -7555) {
                     if (tick == -7557) return 11; else return 11;
                   } else {
                     if (tick == -7555) return 11; else return 11;
                   }
                 }
               } else {
                 if (tick < -7549) {
                   if (tick < -7551) {
                     if (tick == -7553) return 11; else return 12;
                   } else {
                     if (tick == -7551) return 12; else return 12;
                   }
                 } else {
                   if (tick < -7547) {
                     if (tick == -7549) return 12; else return 12;
                   } else {
                     if (tick < -7546) {
                       return 12;
                     } else {
                       if (tick == -7546) return 12; else return 12;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7535) {
                 if (tick < -7540) {
                   if (tick < -7542) {
                     if (tick == -7544) return 13; else return 13;
                   } else {
                     if (tick == -7542) return 13; else return 13;
                   }
                 } else {
                   if (tick < -7538) {
                     if (tick == -7540) return 13; else return 13;
                   } else {
                     if (tick < -7537) {
                       return 13;
                     } else {
                       if (tick == -7537) return 13; else return 14;
                     }
                   }
                 }
               } else {
                 if (tick < -7531) {
                   if (tick < -7533) {
                     if (tick == -7535) return 14; else return 14;
                   } else {
                     if (tick == -7533) return 14; else return 14;
                   }
                 } else {
                   if (tick < -7529) {
                     if (tick == -7531) return 14; else return 14;
                   } else {
                     if (tick < -7528) {
                       return 15;
                     } else {
                       if (tick == -7528) return 15; else return 15;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -7492) {
             if (tick < -7509) {
               if (tick < -7518) {
                 if (tick < -7522) {
                   if (tick < -7524) {
                     if (tick == -7526) return 15; else return 15;
                   } else {
                     if (tick == -7524) return 15; else return 16;
                   }
                 } else {
                   if (tick < -7520) {
                     if (tick == -7522) return 16; else return 16;
                   } else {
                     if (tick == -7520) return 16; else return 16;
                   }
                 }
               } else {
                 if (tick < -7514) {
                   if (tick < -7516) {
                     if (tick == -7518) return 16; else return 17;
                   } else {
                     if (tick == -7516) return 17; else return 17;
                   }
                 } else {
                   if (tick < -7512) {
                     if (tick == -7514) return 17; else return 17;
                   } else {
                     if (tick < -7511) {
                       return 17;
                     } else {
                       if (tick == -7511) return 18; else return 18;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7501) {
                 if (tick < -7505) {
                   if (tick < -7507) {
                     if (tick == -7509) return 18; else return 18;
                   } else {
                     if (tick == -7507) return 18; else return 19;
                   }
                 } else {
                   if (tick < -7503) {
                     if (tick == -7505) return 19; else return 19;
                   } else {
                     if (tick == -7503) return 19; else return 19;
                   }
                 }
               } else {
                 if (tick < -7497) {
                   if (tick < -7499) {
                     if (tick == -7501) return 19; else return 20;
                   } else {
                     if (tick == -7499) return 20; else return 20;
                   }
                 } else {
                   if (tick < -7495) {
                     if (tick == -7497) return 20; else return 21;
                   } else {
                     if (tick < -7494) {
                       return 21;
                     } else {
                       if (tick == -7494) return 21; else return 21;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7475) {
               if (tick < -7484) {
                 if (tick < -7488) {
                   if (tick < -7490) {
                     if (tick == -7492) return 21; else return 22;
                   } else {
                     if (tick == -7490) return 22; else return 22;
                   }
                 } else {
                   if (tick < -7486) {
                     if (tick == -7488) return 22; else return 22;
                   } else {
                     if (tick == -7486) return 23; else return 23;
                   }
                 }
               } else {
                 if (tick < -7480) {
                   if (tick < -7482) {
                     if (tick == -7484) return 23; else return 23;
                   } else {
                     if (tick == -7482) return 24; else return 24;
                   }
                 } else {
                   if (tick < -7478) {
                     if (tick == -7480) return 24; else return 24;
                   } else {
                     if (tick < -7477) {
                       return 25;
                     } else {
                       if (tick == -7477) return 25; else return 25;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7466) {
                 if (tick < -7471) {
                   if (tick < -7473) {
                     if (tick == -7475) return 25; else return 26;
                   } else {
                     if (tick == -7473) return 26; else return 26;
                   }
                 } else {
                   if (tick < -7469) {
                     if (tick == -7471) return 26; else return 27;
                   } else {
                     if (tick < -7468) {
                       return 27;
                     } else {
                       if (tick == -7468) return 27; else return 28;
                     }
                   }
                 }
               } else {
                 if (tick < -7462) {
                   if (tick < -7464) {
                     if (tick == -7466) return 28; else return 28;
                   } else {
                     if (tick == -7464) return 28; else return 29;
                   }
                 } else {
                   if (tick < -7460) {
                     if (tick == -7462) return 29; else return 29;
                   } else {
                     if (tick < -7459) {
                       return 30;
                     } else {
                       if (tick == -7459) return 30; else return 30;
                     }
                   }
                 }
               }
             }
           }
         }
       }
     } else {
       if (tick < -7320) {
         if (tick < -7389) {
           if (tick < -7423) {
             if (tick < -7440) {
               if (tick < -7449) {
                 if (tick < -7453) {
                   if (tick < -7455) {
                     if (tick == -7457) return 30; else return 31;
                   } else {
                     if (tick == -7455) return 31; else return 31;
                   }
                 } else {
                   if (tick < -7451) {
                     if (tick == -7453) return 32; else return 32;
                   } else {
                     if (tick == -7451) return 32; else return 33;
                   }
                 }
               } else {
                 if (tick < -7445) {
                   if (tick < -7447) {
                     if (tick == -7449) return 33; else return 33;
                   } else {
                     if (tick == -7447) return 34; else return 34;
                   }
                 } else {
                   if (tick < -7443) {
                     if (tick == -7445) return 34; else return 35;
                   } else {
                     if (tick < -7442) {
                       return 35;
                     } else {
                       if (tick == -7442) return 35; else return 36;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7432) {
                 if (tick < -7436) {
                   if (tick < -7438) {
                     if (tick == -7440) return 36; else return 37;
                   } else {
                     if (tick == -7438) return 37; else return 37;
                   }
                 } else {
                   if (tick < -7434) {
                     if (tick == -7436) return 38; else return 38;
                   } else {
                     if (tick == -7434) return 38; else return 39;
                   }
                 }
               } else {
                 if (tick < -7428) {
                   if (tick < -7430) {
                     if (tick == -7432) return 39; else return 40;
                   } else {
                     if (tick == -7430) return 40; else return 40;
                   }
                 } else {
                   if (tick < -7426) {
                     if (tick == -7428) return 41; else return 41;
                   } else {
                     if (tick < -7425) {
                       return 42;
                     } else {
                       if (tick == -7425) return 42; else return 43;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7406) {
               if (tick < -7415) {
                 if (tick < -7419) {
                   if (tick < -7421) {
                     if (tick == -7423) return 43; else return 43;
                   } else {
                     if (tick == -7421) return 44; else return 44;
                   }
                 } else {
                   if (tick < -7417) {
                     if (tick == -7419) return 45; else return 45;
                   } else {
                     if (tick == -7417) return 46; else return 46;
                   }
                 }
               } else {
                 if (tick < -7411) {
                   if (tick < -7413) {
                     if (tick == -7415) return 47; else return 47;
                   } else {
                     if (tick == -7413) return 47; else return 48;
                   }
                 } else {
                   if (tick < -7409) {
                     if (tick == -7411) return 48; else return 49;
                   } else {
                     if (tick < -7408) {
                       return 49;
                     } else {
                       if (tick == -7408) return 50; else return 50;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7398) {
                 if (tick < -7402) {
                   if (tick < -7404) {
                     if (tick == -7406) return 51; else return 51;
                   } else {
                     if (tick == -7404) return 52; else return 52;
                   }
                 } else {
                   if (tick < -7400) {
                     if (tick == -7402) return 53; else return 54;
                   } else {
                     if (tick == -7400) return 54; else return 55;
                   }
                 }
               } else {
                 if (tick < -7394) {
                   if (tick < -7396) {
                     if (tick == -7398) return 55; else return 56;
                   } else {
                     if (tick == -7396) return 56; else return 57;
                   }
                 } else {
                   if (tick < -7392) {
                     if (tick == -7394) return 57; else return 58;
                   } else {
                     if (tick < -7391) {
                       return 59;
                     } else {
                       if (tick == -7391) return 59; else return 60;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -7355) {
             if (tick < -7372) {
               if (tick < -7381) {
                 if (tick < -7385) {
                   if (tick < -7387) {
                     if (tick == -7389) return 60; else return 61;
                   } else {
                     if (tick == -7387) return 62; else return 62;
                   }
                 } else {
                   if (tick < -7383) {
                     if (tick == -7385) return 63; else return 64;
                   } else {
                     if (tick == -7383) return 64; else return 65;
                   }
                 }
               } else {
                 if (tick < -7377) {
                   if (tick < -7379) {
                     if (tick == -7381) return 65; else return 66;
                   } else {
                     if (tick == -7379) return 67; else return 67;
                   }
                 } else {
                   if (tick < -7375) {
                     if (tick == -7377) return 68; else return 69;
                   } else {
                     if (tick < -7374) {
                       return 70;
                     } else {
                       if (tick == -7374) return 70; else return 71;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7364) {
                 if (tick < -7368) {
                   if (tick < -7370) {
                     if (tick == -7372) return 72; else return 72;
                   } else {
                     if (tick == -7370) return 73; else return 74;
                   }
                 } else {
                   if (tick < -7366) {
                     if (tick == -7368) return 75; else return 75;
                   } else {
                     if (tick == -7366) return 76; else return 77;
                   }
                 }
               } else {
                 if (tick < -7360) {
                   if (tick < -7362) {
                     if (tick == -7364) return 78; else return 78;
                   } else {
                     if (tick == -7362) return 79; else return 80;
                   }
                 } else {
                   if (tick < -7358) {
                     if (tick == -7360) return 81; else return 82;
                   } else {
                     if (tick < -7357) {
                       return 82;
                     } else {
                       if (tick == -7357) return 83; else return 84;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7338) {
               if (tick < -7347) {
                 if (tick < -7351) {
                   if (tick < -7353) {
                     if (tick == -7355) return 85; else return 86;
                   } else {
                     if (tick == -7353) return 87; else return 88;
                   }
                 } else {
                   if (tick < -7349) {
                     if (tick == -7351) return 88; else return 89;
                   } else {
                     if (tick == -7349) return 90; else return 91;
                   }
                 }
               } else {
                 if (tick < -7343) {
                   if (tick < -7345) {
                     if (tick == -7347) return 92; else return 93;
                   } else {
                     if (tick == -7345) return 94; else return 95;
                   }
                 } else {
                   if (tick < -7341) {
                     if (tick == -7343) return 96; else return 97;
                   } else {
                     if (tick < -7340) {
                       return 98;
                     } else {
                       if (tick == -7340) return 99; else return 100;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7329) {
                 if (tick < -7334) {
                   if (tick < -7336) {
                     if (tick == -7338) return 101; else return 102;
                   } else {
                     if (tick == -7336) return 103; else return 104;
                   }
                 } else {
                   if (tick < -7332) {
                     if (tick == -7334) return 105; else return 106;
                   } else {
                     if (tick < -7331) {
                       return 107;
                     } else {
                       if (tick == -7331) return 108; else return 109;
                     }
                   }
                 }
               } else {
                 if (tick < -7325) {
                   if (tick < -7327) {
                     if (tick == -7329) return 110; else return 111;
                   } else {
                     if (tick == -7327) return 112; else return 114;
                   }
                 } else {
                   if (tick < -7323) {
                     if (tick == -7325) return 115; else return 116;
                   } else {
                     if (tick < -7322) {
                       return 117;
                     } else {
                       if (tick == -7322) return 118; else return 119;
                     }
                   }
                 }
               }
             }
           }
         }
       } else {
         if (tick < -7251) {
           if (tick < -7286) {
             if (tick < -7303) {
               if (tick < -7312) {
                 if (tick < -7316) {
                   if (tick < -7318) {
                     if (tick == -7320) return 121; else return 122;
                   } else {
                     if (tick == -7318) return 123; else return 124;
                   }
                 } else {
                   if (tick < -7314) {
                     if (tick == -7316) return 125; else return 127;
                   } else {
                     if (tick == -7314) return 128; else return 129;
                   }
                 }
               } else {
                 if (tick < -7308) {
                   if (tick < -7310) {
                     if (tick == -7312) return 131; else return 132;
                   } else {
                     if (tick == -7310) return 133; else return 135;
                   }
                 } else {
                   if (tick < -7306) {
                     if (tick == -7308) return 136; else return 137;
                   } else {
                     if (tick < -7305) {
                       return 139;
                     } else {
                       if (tick == -7305) return 140; else return 141;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7295) {
                 if (tick < -7299) {
                   if (tick < -7301) {
                     if (tick == -7303) return 143; else return 144;
                   } else {
                     if (tick == -7301) return 146; else return 147;
                   }
                 } else {
                   if (tick < -7297) {
                     if (tick == -7299) return 149; else return 150;
                   } else {
                     if (tick == -7297) return 152; else return 153;
                   }
                 }
               } else {
                 if (tick < -7291) {
                   if (tick < -7293) {
                     if (tick == -7295) return 155; else return 156;
                   } else {
                     if (tick == -7293) return 158; else return 159;
                   }
                 } else {
                   if (tick < -7289) {
                     if (tick == -7291) return 161; else return 163;
                   } else {
                     if (tick < -7288) {
                       return 164;
                     } else {
                       if (tick == -7288) return 166; else return 168;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7269) {
               if (tick < -7278) {
                 if (tick < -7282) {
                   if (tick < -7284) {
                     if (tick == -7286) return 169; else return 171;
                   } else {
                     if (tick == -7284) return 173; else return 174;
                   }
                 } else {
                   if (tick < -7280) {
                     if (tick == -7282) return 176; else return 178;
                   } else {
                     if (tick == -7280) return 180; else return 182;
                   }
                 }
               } else {
                 if (tick < -7274) {
                   if (tick < -7276) {
                     if (tick == -7278) return 183; else return 185;
                   } else {
                     if (tick == -7276) return 187; else return 189;
                   }
                 } else {
                   if (tick < -7272) {
                     if (tick == -7274) return 191; else return 193;
                   } else {
                     if (tick < -7271) {
                       return 195;
                     } else {
                       if (tick == -7271) return 197; else return 199;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7260) {
                 if (tick < -7265) {
                   if (tick < -7267) {
                     if (tick == -7269) return 201; else return 203;
                   } else {
                     if (tick == -7267) return 205; else return 207;
                   }
                 } else {
                   if (tick < -7263) {
                     if (tick == -7265) return 209; else return 211;
                   } else {
                     if (tick < -7262) {
                       return 213;
                     } else {
                       if (tick == -7262) return 215; else return 217;
                     }
                   }
                 }
               } else {
                 if (tick < -7256) {
                   if (tick < -7258) {
                     if (tick == -7260) return 219; else return 222;
                   } else {
                     if (tick == -7258) return 224; else return 226;
                   }
                 } else {
                   if (tick < -7254) {
                     if (tick == -7256) return 228; else return 231;
                   } else {
                     if (tick < -7253) {
                       return 233;
                     } else {
                       if (tick == -7253) return 235; else return 238;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -7217) {
             if (tick < -7234) {
               if (tick < -7243) {
                 if (tick < -7247) {
                   if (tick < -7249) {
                     if (tick == -7251) return 240; else return 242;
                   } else {
                     if (tick == -7249) return 245; else return 247;
                   }
                 } else {
                   if (tick < -7245) {
                     if (tick == -7247) return 250; else return 252;
                   } else {
                     if (tick == -7245) return 255; else return 257;
                   }
                 }
               } else {
                 if (tick < -7239) {
                   if (tick < -7241) {
                     if (tick == -7243) return 260; else return 263;
                   } else {
                     if (tick == -7241) return 265; else return 268;
                   }
                 } else {
                   if (tick < -7237) {
                     if (tick == -7239) return 270; else return 273;
                   } else {
                     if (tick < -7236) {
                       return 276;
                     } else {
                       if (tick == -7236) return 279; else return 281;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7226) {
                 if (tick < -7230) {
                   if (tick < -7232) {
                     if (tick == -7234) return 284; else return 287;
                   } else {
                     if (tick == -7232) return 290; else return 293;
                   }
                 } else {
                   if (tick < -7228) {
                     if (tick == -7230) return 296; else return 299;
                   } else {
                     if (tick == -7228) return 302; else return 305;
                   }
                 }
               } else {
                 if (tick < -7222) {
                   if (tick < -7224) {
                     if (tick == -7226) return 308; else return 311;
                   } else {
                     if (tick == -7224) return 314; else return 317;
                   }
                 } else {
                   if (tick < -7220) {
                     if (tick == -7222) return 320; else return 324;
                   } else {
                     if (tick < -7219) {
                       return 327;
                     } else {
                       if (tick == -7219) return 330; else return 333;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7200) {
               if (tick < -7209) {
                 if (tick < -7213) {
                   if (tick < -7215) {
                     if (tick == -7217) return 337; else return 340;
                   } else {
                     if (tick == -7215) return 344; else return 347;
                   }
                 } else {
                   if (tick < -7211) {
                     if (tick == -7213) return 350; else return 354;
                   } else {
                     if (tick == -7211) return 358; else return 361;
                   }
                 }
               } else {
                 if (tick < -7205) {
                   if (tick < -7207) {
                     if (tick == -7209) return 365; else return 368;
                   } else {
                     if (tick == -7207) return 372; else return 376;
                   }
                 } else {
                   if (tick < -7203) {
                     if (tick == -7205) return 380; else return 383;
                   } else {
                     if (tick < -7202) {
                       return 387;
                     } else {
                       if (tick == -7202) return 391; else return 395;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7191) {
                 if (tick < -7196) {
                   if (tick < -7198) {
                     if (tick == -7200) return 399; else return 403;
                   } else {
                     if (tick == -7198) return 407; else return 411;
                   }
                 } else {
                   if (tick < -7194) {
                     if (tick == -7196) return 415; else return 419;
                   } else {
                     if (tick < -7193) {
                       return 424;
                     } else {
                       if (tick == -7193) return 428; else return 432;
                     }
                   }
                 }
               } else {
                 if (tick < -7187) {
                   if (tick < -7189) {
                     if (tick == -7191) return 436; else return 441;
                   } else {
                     if (tick == -7189) return 445; else return 450;
                   }
                 } else {
                   if (tick < -7185) {
                     if (tick == -7187) return 454; else return 459;
                   } else {
                     if (tick < -7184) {
                       return 463;
                     } else {
                       if (tick == -7184) return 468; else return 473;
                     }
                   }
                 }
               }
             }
           }
         }
       }
     }
   } else {
     if (tick < -6907) {
       if (tick < -7045) {
         if (tick < -7114) {
           if (tick < -7148) {
             if (tick < -7165) {
               if (tick < -7174) {
                 if (tick < -7178) {
                   if (tick < -7180) {
                     if (tick == -7182) return 477; else return 482;
                   } else {
                     if (tick == -7180) return 487; else return 492;
                   }
                 } else {
                   if (tick < -7176) {
                     if (tick == -7178) return 497; else return 502;
                   } else {
                     if (tick == -7176) return 507; else return 512;
                   }
                 }
               } else {
                 if (tick < -7170) {
                   if (tick < -7172) {
                     if (tick == -7174) return 517; else return 522;
                   } else {
                     if (tick == -7172) return 527; else return 533;
                   }
                 } else {
                   if (tick < -7168) {
                     if (tick == -7170) return 538; else return 543;
                   } else {
                     if (tick < -7167) {
                       return 549;
                     } else {
                       if (tick == -7167) return 554; else return 560;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7157) {
                 if (tick < -7161) {
                   if (tick < -7163) {
                     if (tick == -7165) return 565; else return 571;
                   } else {
                     if (tick == -7163) return 577; else return 583;
                   }
                 } else {
                   if (tick < -7159) {
                     if (tick == -7161) return 588; else return 594;
                   } else {
                     if (tick == -7159) return 600; else return 606;
                   }
                 }
               } else {
                 if (tick < -7153) {
                   if (tick < -7155) {
                     if (tick == -7157) return 612; else return 618;
                   } else {
                     if (tick == -7155) return 625; else return 631;
                   }
                 } else {
                   if (tick < -7151) {
                     if (tick == -7153) return 637; else return 644;
                   } else {
                     if (tick < -7150) {
                       return 650;
                     } else {
                       if (tick == -7150) return 656; else return 663;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7131) {
               if (tick < -7140) {
                 if (tick < -7144) {
                   if (tick < -7146) {
                     if (tick == -7148) return 670; else return 676;
                   } else {
                     if (tick == -7146) return 683; else return 690;
                   }
                 } else {
                   if (tick < -7142) {
                     if (tick == -7144) return 697; else return 704;
                   } else {
                     if (tick == -7142) return 711; else return 718;
                   }
                 }
               } else {
                 if (tick < -7136) {
                   if (tick < -7138) {
                     if (tick == -7140) return 725; else return 732;
                   } else {
                     if (tick == -7138) return 740; else return 747;
                   }
                 } else {
                   if (tick < -7134) {
                     if (tick == -7136) return 755; else return 762;
                   } else {
                     if (tick < -7133) {
                       return 770;
                     } else {
                       if (tick == -7133) return 778; else return 785;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7123) {
                 if (tick < -7127) {
                   if (tick < -7129) {
                     if (tick == -7131) return 793; else return 801;
                   } else {
                     if (tick == -7129) return 809; else return 817;
                   }
                 } else {
                   if (tick < -7125) {
                     if (tick == -7127) return 825; else return 834;
                   } else {
                     if (tick == -7125) return 842; else return 850;
                   }
                 }
               } else {
                 if (tick < -7119) {
                   if (tick < -7121) {
                     if (tick == -7123) return 859; else return 868;
                   } else {
                     if (tick == -7121) return 876; else return 885;
                   }
                 } else {
                   if (tick < -7117) {
                     if (tick == -7119) return 894; else return 903;
                   } else {
                     if (tick < -7116) {
                       return 912;
                     } else {
                       if (tick == -7116) return 921; else return 930;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -7080) {
             if (tick < -7097) {
               if (tick < -7106) {
                 if (tick < -7110) {
                   if (tick < -7112) {
                     if (tick == -7114) return 939; else return 949;
                   } else {
                     if (tick == -7112) return 958; else return 968;
                   }
                 } else {
                   if (tick < -7108) {
                     if (tick == -7110) return 978; else return 987;
                   } else {
                     if (tick == -7108) return 997; else return 1007;
                   }
                 }
               } else {
                 if (tick < -7102) {
                   if (tick < -7104) {
                     if (tick == -7106) return 1017; else return 1028;
                   } else {
                     if (tick == -7104) return 1038; else return 1048;
                   }
                 } else {
                   if (tick < -7100) {
                     if (tick == -7102) return 1059; else return 1069;
                   } else {
                     if (tick < -7099) {
                       return 1080;
                     } else {
                       if (tick == -7099) return 1091; else return 1102;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7089) {
                 if (tick < -7093) {
                   if (tick < -7095) {
                     if (tick == -7097) return 1113; else return 1124;
                   } else {
                     if (tick == -7095) return 1135; else return 1146;
                   }
                 } else {
                   if (tick < -7091) {
                     if (tick == -7093) return 1158; else return 1169;
                   } else {
                     if (tick == -7091) return 1181; else return 1193;
                   }
                 }
               } else {
                 if (tick < -7085) {
                   if (tick < -7087) {
                     if (tick == -7089) return 1205; else return 1217;
                   } else {
                     if (tick == -7087) return 1229; else return 1241;
                   }
                 } else {
                   if (tick < -7083) {
                     if (tick == -7085) return 1254; else return 1266;
                   } else {
                     if (tick < -7082) {
                       return 1279;
                     } else {
                       if (tick == -7082) return 1292; else return 1305;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -7063) {
               if (tick < -7072) {
                 if (tick < -7076) {
                   if (tick < -7078) {
                     if (tick == -7080) return 1318; else return 1331;
                   } else {
                     if (tick == -7078) return 1344; else return 1358;
                   }
                 } else {
                   if (tick < -7074) {
                     if (tick == -7076) return 1371; else return 1385;
                   } else {
                     if (tick == -7074) return 1399; else return 1413;
                   }
                 }
               } else {
                 if (tick < -7068) {
                   if (tick < -7070) {
                     if (tick == -7072) return 1427; else return 1441;
                   } else {
                     if (tick == -7070) return 1456; else return 1470;
                   }
                 } else {
                   if (tick < -7066) {
                     if (tick == -7068) return 1485; else return 1500;
                   } else {
                     if (tick < -7065) {
                       return 1515;
                     } else {
                       if (tick == -7065) return 1530; else return 1545;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7054) {
                 if (tick < -7059) {
                   if (tick < -7061) {
                     if (tick == -7063) return 1561; else return 1576;
                   } else {
                     if (tick == -7061) return 1592; else return 1608;
                   }
                 } else {
                   if (tick < -7057) {
                     if (tick == -7059) return 1624; else return 1640;
                   } else {
                     if (tick < -7056) {
                       return 1657;
                     } else {
                       if (tick == -7056) return 1673; else return 1690;
                     }
                   }
                 }
               } else {
                 if (tick < -7050) {
                   if (tick < -7052) {
                     if (tick == -7054) return 1707; else return 1724;
                   } else {
                     if (tick == -7052) return 1741; else return 1759;
                   }
                 } else {
                   if (tick < -7048) {
                     if (tick == -7050) return 1776; else return 1794;
                   } else {
                     if (tick < -7047) {
                       return 1812;
                     } else {
                       if (tick == -7047) return 1830; else return 1849;
                     }
                   }
                 }
               }
             }
           }
         }
       } else {
         if (tick < -6976) {
           if (tick < -7011) {
             if (tick < -7028) {
               if (tick < -7037) {
                 if (tick < -7041) {
                   if (tick < -7043) {
                     if (tick == -7045) return 1867; else return 1886;
                   } else {
                     if (tick == -7043) return 1905; else return 1924;
                   }
                 } else {
                   if (tick < -7039) {
                     if (tick == -7041) return 1943; else return 1962;
                   } else {
                     if (tick == -7039) return 1982; else return 2002;
                   }
                 }
               } else {
                 if (tick < -7033) {
                   if (tick < -7035) {
                     if (tick == -7037) return 2022; else return 2042;
                   } else {
                     if (tick == -7035) return 2062; else return 2083;
                   }
                 } else {
                   if (tick < -7031) {
                     if (tick == -7033) return 2104; else return 2125;
                   } else {
                     if (tick < -7030) {
                       return 2146;
                     } else {
                       if (tick == -7030) return 2168; else return 2189;
                     }
                   }
                 }
               }
             } else {
               if (tick < -7020) {
                 if (tick < -7024) {
                   if (tick < -7026) {
                     if (tick == -7028) return 2211; else return 2233;
                   } else {
                     if (tick == -7026) return 2256; else return 2278;
                   }
                 } else {
                   if (tick < -7022) {
                     if (tick == -7024) return 2301; else return 2324;
                   } else {
                     if (tick == -7022) return 2347; else return 2371;
                   }
                 }
               } else {
                 if (tick < -7016) {
                   if (tick < -7018) {
                     if (tick == -7020) return 2395; else return 2419;
                   } else {
                     if (tick == -7018) return 2443; else return 2467;
                   }
                 } else {
                   if (tick < -7014) {
                     if (tick == -7016) return 2492; else return 2517;
                   } else {
                     if (tick < -7013) {
                       return 2542;
                     } else {
                       if (tick == -7013) return 2567; else return 2593;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -6994) {
               if (tick < -7003) {
                 if (tick < -7007) {
                   if (tick < -7009) {
                     if (tick == -7011) return 2619; else return 2645;
                   } else {
                     if (tick == -7009) return 2672; else return 2698;
                   }
                 } else {
                   if (tick < -7005) {
                     if (tick == -7007) return 2725; else return 2753;
                   } else {
                     if (tick == -7005) return 2780; else return 2808;
                   }
                 }
               } else {
                 if (tick < -6999) {
                   if (tick < -7001) {
                     if (tick == -7003) return 2836; else return 2864;
                   } else {
                     if (tick == -7001) return 2893; else return 2922;
                   }
                 } else {
                   if (tick < -6997) {
                     if (tick == -6999) return 2951; else return 2981;
                   } else {
                     if (tick < -6996) {
                       return 3010;
                     } else {
                       if (tick == -6996) return 3041; else return 3071;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6985) {
                 if (tick < -6990) {
                   if (tick < -6992) {
                     if (tick == -6994) return 3102; else return 3133;
                   } else {
                     if (tick == -6992) return 3164; else return 3196;
                   }
                 } else {
                   if (tick < -6988) {
                     if (tick == -6990) return 3228; else return 3260;
                   } else {
                     if (tick < -6987) {
                       return 3293;
                     } else {
                       if (tick == -6987) return 3325; else return 3359;
                     }
                   }
                 }
               } else {
                 if (tick < -6981) {
                   if (tick < -6983) {
                     if (tick == -6985) return 3392; else return 3426;
                   } else {
                     if (tick == -6983) return 3461; else return 3495;
                   }
                 } else {
                   if (tick < -6979) {
                     if (tick == -6981) return 3530; else return 3565;
                   } else {
                     if (tick < -6978) {
                       return 3601;
                     } else {
                       if (tick == -6978) return 3637; else return 3673;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -6942) {
             if (tick < -6959) {
               if (tick < -6968) {
                 if (tick < -6972) {
                   if (tick < -6974) {
                     if (tick == -6976) return 3710; else return 3747;
                   } else {
                     if (tick == -6974) return 3785; else return 3823;
                   }
                 } else {
                   if (tick < -6970) {
                     if (tick == -6972) return 3861; else return 3899;
                   } else {
                     if (tick == -6970) return 3938; else return 3978;
                   }
                 }
               } else {
                 if (tick < -6964) {
                   if (tick < -6966) {
                     if (tick == -6968) return 4018; else return 4058;
                   } else {
                     if (tick == -6966) return 4098; else return 4139;
                   }
                 } else {
                   if (tick < -6962) {
                     if (tick == -6964) return 4181; else return 4223;
                   } else {
                     if (tick < -6961) {
                       return 4265;
                     } else {
                       if (tick == -6961) return 4308; else return 4351;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6951) {
                 if (tick < -6955) {
                   if (tick < -6957) {
                     if (tick == -6959) return 4394; else return 4438;
                   } else {
                     if (tick == -6957) return 4482; else return 4527;
                   }
                 } else {
                   if (tick < -6953) {
                     if (tick == -6955) return 4573; else return 4618;
                   } else {
                     if (tick == -6953) return 4664; else return 4711;
                   }
                 }
               } else {
                 if (tick < -6947) {
                   if (tick < -6949) {
                     if (tick == -6951) return 4758; else return 4806;
                   } else {
                     if (tick == -6949) return 4854; else return 4902;
                   }
                 } else {
                   if (tick < -6945) {
                     if (tick == -6947) return 4951; else return 5001;
                   } else {
                     if (tick < -6944) {
                       return 5051;
                     } else {
                       if (tick == -6944) return 5101; else return 5153;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -6925) {
               if (tick < -6934) {
                 if (tick < -6938) {
                   if (tick < -6940) {
                     if (tick == -6942) return 5204; else return 5256;
                   } else {
                     if (tick == -6940) return 5309; else return 5362;
                   }
                 } else {
                   if (tick < -6936) {
                     if (tick == -6938) return 5415; else return 5470;
                   } else {
                     if (tick == -6936) return 5524; else return 5579;
                   }
                 }
               } else {
                 if (tick < -6930) {
                   if (tick < -6932) {
                     if (tick == -6934) return 5635; else return 5692;
                   } else {
                     if (tick == -6932) return 5749; else return 5806;
                   }
                 } else {
                   if (tick < -6928) {
                     if (tick == -6930) return 5864; else return 5923;
                   } else {
                     if (tick < -6927) {
                       return 5982;
                     } else {
                       if (tick == -6927) return 6042; else return 6102;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6916) {
                 if (tick < -6921) {
                   if (tick < -6923) {
                     if (tick == -6925) return 6163; else return 6225;
                   } else {
                     if (tick == -6923) return 6287; else return 6350;
                   }
                 } else {
                   if (tick < -6919) {
                     if (tick == -6921) return 6414; else return 6478;
                   } else {
                     if (tick < -6918) {
                       return 6542;
                     } else {
                       if (tick == -6918) return 6608; else return 6674;
                     }
                   }
                 }
               } else {
                 if (tick < -6912) {
                   if (tick < -6914) {
                     if (tick == -6916) return 6741; else return 6808;
                   } else {
                     if (tick == -6914) return 6876; else return 6945;
                   }
                 } else {
                   if (tick < -6910) {
                     if (tick == -6912) return 7014; else return 7085;
                   } else {
                     if (tick < -6909) {
                       return 7155;
                     } else {
                       if (tick == -6909) return 7227; else return 7299;
                     }
                   }
                 }
               }
             }
           }
         }
       }
     } else {
       if (tick < -6770) {
         if (tick < -6839) {
           if (tick < -6873) {
             if (tick < -6890) {
               if (tick < -6899) {
                 if (tick < -6903) {
                   if (tick < -6905) {
                     if (tick == -6907) return 7372; else return 7446;
                   } else {
                     if (tick == -6905) return 7520; else return 7596;
                   }
                 } else {
                   if (tick < -6901) {
                     if (tick == -6903) return 7672; else return 7748;
                   } else {
                     if (tick == -6901) return 7826; else return 7904;
                   }
                 }
               } else {
                 if (tick < -6895) {
                   if (tick < -6897) {
                     if (tick == -6899) return 7983; else return 8063;
                   } else {
                     if (tick == -6897) return 8144; else return 8225;
                   }
                 } else {
                   if (tick < -6893) {
                     if (tick == -6895) return 8307; else return 8390;
                   } else {
                     if (tick < -6892) {
                       return 8474;
                     } else {
                       if (tick == -6892) return 8559; else return 8645;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6882) {
                 if (tick < -6886) {
                   if (tick < -6888) {
                     if (tick == -6890) return 8731; else return 8818;
                   } else {
                     if (tick == -6888) return 8907; else return 8996;
                   }
                 } else {
                   if (tick < -6884) {
                     if (tick == -6886) return 9086; else return 9177;
                   } else {
                     if (tick == -6884) return 9268; else return 9361;
                   }
                 }
               } else {
                 if (tick < -6878) {
                   if (tick < -6880) {
                     if (tick == -6882) return 9455; else return 9549;
                   } else {
                     if (tick == -6880) return 9645; else return 9741;
                   }
                 } else {
                   if (tick < -6876) {
                     if (tick == -6878) return 9838; else return 9937;
                   } else {
                     if (tick < -6875) {
                       return 10036;
                     } else {
                       if (tick == -6875) return 10137; else return 10238;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -6856) {
               if (tick < -6865) {
                 if (tick < -6869) {
                   if (tick < -6871) {
                     if (tick == -6873) return 10340; else return 10444;
                   } else {
                     if (tick == -6871) return 10548; else return 10654;
                   }
                 } else {
                   if (tick < -6867) {
                     if (tick == -6869) return 10760; else return 10868;
                   } else {
                     if (tick == -6867) return 10977; else return 11086;
                   }
                 }
               } else {
                 if (tick < -6861) {
                   if (tick < -6863) {
                     if (tick == -6865) return 11197; else return 11309;
                   } else {
                     if (tick == -6863) return 11422; else return 11536;
                   }
                 } else {
                   if (tick < -6859) {
                     if (tick == -6861) return 11652; else return 11768;
                   } else {
                     if (tick < -6858) {
                       return 11886;
                     } else {
                       if (tick == -6858) return 12005; else return 12125;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6848) {
                 if (tick < -6852) {
                   if (tick < -6854) {
                     if (tick == -6856) return 12246; else return 12369;
                   } else {
                     if (tick == -6854) return 12492; else return 12617;
                   }
                 } else {
                   if (tick < -6850) {
                     if (tick == -6852) return 12744; else return 12871;
                   } else {
                     if (tick == -6850) return 13000; else return 13130;
                   }
                 }
               } else {
                 if (tick < -6844) {
                   if (tick < -6846) {
                     if (tick == -6848) return 13261; else return 13394;
                   } else {
                     if (tick == -6846) return 13528; else return 13663;
                   }
                 } else {
                   if (tick < -6842) {
                     if (tick == -6844) return 13799; else return 13937;
                   } else {
                     if (tick < -6841) {
                       return 14077;
                     } else {
                       if (tick == -6841) return 14218; else return 14360;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -6805) {
             if (tick < -6822) {
               if (tick < -6831) {
                 if (tick < -6835) {
                   if (tick < -6837) {
                     if (tick == -6839) return 14503; else return 14648;
                   } else {
                     if (tick == -6837) return 14795; else return 14943;
                   }
                 } else {
                   if (tick < -6833) {
                     if (tick == -6835) return 15092; else return 15243;
                   } else {
                     if (tick == -6833) return 15396; else return 15550;
                   }
                 }
               } else {
                 if (tick < -6827) {
                   if (tick < -6829) {
                     if (tick == -6831) return 15705; else return 15862;
                   } else {
                     if (tick == -6829) return 16021; else return 16181;
                   }
                 } else {
                   if (tick < -6825) {
                     if (tick == -6827) return 16343; else return 16506;
                   } else {
                     if (tick < -6824) {
                       return 16671;
                     } else {
                       if (tick == -6824) return 16838; else return 17006;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6814) {
                 if (tick < -6818) {
                   if (tick < -6820) {
                     if (tick == -6822) return 17177; else return 17348;
                   } else {
                     if (tick == -6820) return 17522; else return 17697;
                   }
                 } else {
                   if (tick < -6816) {
                     if (tick == -6818) return 17874; else return 18053;
                   } else {
                     if (tick == -6816) return 18233; else return 18416;
                   }
                 }
               } else {
                 if (tick < -6810) {
                   if (tick < -6812) {
                     if (tick == -6814) return 18600; else return 18786;
                   } else {
                     if (tick == -6812) return 18974; else return 19163;
                   }
                 } else {
                   if (tick < -6808) {
                     if (tick == -6810) return 19355; else return 19549;
                   } else {
                     if (tick < -6807) {
                       return 19744;
                     } else {
                       if (tick == -6807) return 19941; else return 20141;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -6788) {
               if (tick < -6797) {
                 if (tick < -6801) {
                   if (tick < -6803) {
                     if (tick == -6805) return 20342; else return 20546;
                   } else {
                     if (tick == -6803) return 20751; else return 20959;
                   }
                 } else {
                   if (tick < -6799) {
                     if (tick == -6801) return 21168; else return 21380;
                   } else {
                     if (tick == -6799) return 21594; else return 21810;
                   }
                 }
               } else {
                 if (tick < -6793) {
                   if (tick < -6795) {
                     if (tick == -6797) return 22028; else return 22248;
                   } else {
                     if (tick == -6795) return 22471; else return 22695;
                   }
                 } else {
                   if (tick < -6791) {
                     if (tick == -6793) return 22922; else return 23152;
                   } else {
                     if (tick < -6790) {
                       return 23383;
                     } else {
                       if (tick == -6790) return 23617; else return 23853;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6779) {
                 if (tick < -6784) {
                   if (tick < -6786) {
                     if (tick == -6788) return 24092; else return 24332;
                   } else {
                     if (tick == -6786) return 24576; else return 24822;
                   }
                 } else {
                   if (tick < -6782) {
                     if (tick == -6784) return 25070; else return 25321;
                   } else {
                     if (tick < -6781) {
                       return 25574;
                     } else {
                       if (tick == -6781) return 25829; else return 26088;
                     }
                   }
                 }
               } else {
                 if (tick < -6775) {
                   if (tick < -6777) {
                     if (tick == -6779) return 26349; else return 26612;
                   } else {
                     if (tick == -6777) return 26878; else return 27147;
                   }
                 } else {
                   if (tick < -6773) {
                     if (tick == -6775) return 27419; else return 27693;
                   } else {
                     if (tick < -6772) {
                       return 27970;
                     } else {
                       if (tick == -6772) return 28249; else return 28532;
                     }
                   }
                 }
               }
             }
           }
         }
       } else {
         if (tick < -6701) {
           if (tick < -6736) {
             if (tick < -6753) {
               if (tick < -6762) {
                 if (tick < -6766) {
                   if (tick < -6768) {
                     if (tick == -6770) return 28817; else return 29105;
                   } else {
                     if (tick == -6768) return 29396; else return 29690;
                   }
                 } else {
                   if (tick < -6764) {
                     if (tick == -6766) return 29987; else return 30287;
                   } else {
                     if (tick == -6764) return 30590; else return 30896;
                   }
                 }
               } else {
                 if (tick < -6758) {
                   if (tick < -6760) {
                     if (tick == -6762) return 31205; else return 31517;
                   } else {
                     if (tick == -6760) return 31832; else return 32150;
                   }
                 } else {
                   if (tick < -6756) {
                     if (tick == -6758) return 32472; else return 32797;
                   } else {
                     if (tick < -6755) {
                       return 33125;
                     } else {
                       if (tick == -6755) return 33456; else return 33790;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6745) {
                 if (tick < -6749) {
                   if (tick < -6751) {
                     if (tick == -6753) return 34128; else return 34470;
                   } else {
                     if (tick == -6751) return 34814; else return 35163;
                   }
                 } else {
                   if (tick < -6747) {
                     if (tick == -6749) return 35514; else return 35869;
                   } else {
                     if (tick == -6747) return 36228; else return 36590;
                   }
                 }
               } else {
                 if (tick < -6741) {
                   if (tick < -6743) {
                     if (tick == -6745) return 36956; else return 37326;
                   } else {
                     if (tick == -6743) return 37699; else return 38076;
                   }
                 } else {
                   if (tick < -6739) {
                     if (tick == -6741) return 38457; else return 38841;
                   } else {
                     if (tick < -6738) {
                       return 39230;
                     } else {
                       if (tick == -6738) return 39622; else return 40018;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -6719) {
               if (tick < -6728) {
                 if (tick < -6732) {
                   if (tick < -6734) {
                     if (tick == -6736) return 40419; else return 40823;
                   } else {
                     if (tick == -6734) return 41231; else return 41643;
                   }
                 } else {
                   if (tick < -6730) {
                     if (tick == -6732) return 42060; else return 42480;
                   } else {
                     if (tick == -6730) return 42905; else return 43334;
                   }
                 }
               } else {
                 if (tick < -6724) {
                   if (tick < -6726) {
                     if (tick == -6728) return 43768; else return 44205;
                   } else {
                     if (tick == -6726) return 44647; else return 45094;
                   }
                 } else {
                   if (tick < -6722) {
                     if (tick == -6724) return 45545; else return 46000;
                   } else {
                     if (tick < -6721) {
                       return 46460;
                     } else {
                       if (tick == -6721) return 46925; else return 47394;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6710) {
                 if (tick < -6715) {
                   if (tick < -6717) {
                     if (tick == -6719) return 47868; else return 48347;
                   } else {
                     if (tick == -6717) return 48830; else return 49318;
                   }
                 } else {
                   if (tick < -6713) {
                     if (tick == -6715) return 49812; else return 50310;
                   } else {
                     if (tick < -6712) {
                       return 50813;
                     } else {
                       if (tick == -6712) return 51321; else return 51834;
                     }
                   }
                 }
               } else {
                 if (tick < -6706) {
                   if (tick < -6708) {
                     if (tick == -6710) return 52352; else return 52876;
                   } else {
                     if (tick == -6708) return 53405; else return 53939;
                   }
                 } else {
                   if (tick < -6704) {
                     if (tick == -6706) return 54478; else return 55023;
                   } else {
                     if (tick < -6703) {
                       return 55573;
                     } else {
                       if (tick == -6703) return 56129; else return 56690;
                     }
                   }
                 }
               }
             }
           }
         } else {
           if (tick < -6667) {
             if (tick < -6684) {
               if (tick < -6693) {
                 if (tick < -6697) {
                   if (tick < -6699) {
                     if (tick == -6701) return 57257; else return 57830;
                   } else {
                     if (tick == -6699) return 58408; else return 58992;
                   }
                 } else {
                   if (tick < -6695) {
                     if (tick == -6697) return 59582; else return 60178;
                   } else {
                     if (tick == -6695) return 60780; else return 61387;
                   }
                 }
               } else {
                 if (tick < -6689) {
                   if (tick < -6691) {
                     if (tick == -6693) return 62001; else return 62621;
                   } else {
                     if (tick == -6691) return 63248; else return 63880;
                   }
                 } else {
                   if (tick < -6687) {
                     if (tick == -6689) return 64519; else return 65164;
                   } else {
                     if (tick < -6686) {
                       return 65816;
                     } else {
                       if (tick == -6686) return 66474; else return 67139;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6676) {
                 if (tick < -6680) {
                   if (tick < -6682) {
                     if (tick == -6684) return 67810; else return 68488;
                   } else {
                     if (tick == -6682) return 69173; else return 69865;
                   }
                 } else {
                   if (tick < -6678) {
                     if (tick == -6680) return 70563; else return 71269;
                   } else {
                     if (tick == -6678) return 71982; else return 72702;
                   }
                 }
               } else {
                 if (tick < -6672) {
                   if (tick < -6674) {
                     if (tick == -6676) return 73429; else return 74163;
                   } else {
                     if (tick == -6674) return 74905; else return 75654;
                   }
                 } else {
                   if (tick < -6670) {
                     if (tick == -6672) return 76410; else return 77174;
                   } else {
                     if (tick < -6669) {
                       return 77946;
                     } else {
                       if (tick == -6669) return 78725; else return 79513;
                     }
                   }
                 }
               }
             }
           } else {
             if (tick < -6650) {
               if (tick < -6659) {
                 if (tick < -6663) {
                   if (tick < -6665) {
                     if (tick == -6667) return 80308; else return 81111;
                   } else {
                     if (tick == -6665) return 81922; else return 82741;
                   }
                 } else {
                   if (tick < -6661) {
                     if (tick == -6663) return 83569; else return 84404;
                   } else {
                     if (tick == -6661) return 85248; else return 86101;
                   }
                 }
               } else {
                 if (tick < -6655) {
                   if (tick < -6657) {
                     if (tick == -6659) return 86962; else return 87832;
                   } else {
                     if (tick == -6657) return 88710; else return 89597;
                   }
                 } else {
                   if (tick < -6653) {
                     if (tick == -6655) return 90493; else return 91398;
                   } else {
                     if (tick < -6652) {
                       return 92312;
                     } else {
                       if (tick == -6652) return 93235; else return 94167;
                     }
                   }
                 }
               }
             } else {
               if (tick < -6641) {
                 if (tick < -6646) {
                   if (tick < -6648) {
                     if (tick == -6650) return 95109; else return 96060;
                   } else {
                     if (tick == -6648) return 97021; else return 97991;
                   }
                 } else {
                   if (tick < -6644) {
                     if (tick == -6646) return 98971; else return 99961;
                   } else {
                     if (tick < -6643) {
                       return 100960;
                     } else {
                       if (tick == -6643) return 101970; else return 102989;
                     }
                   }
                 }
               } else {
                 if (tick < -6637) {
                   if (tick < -6639) {
                     if (tick == -6641) return 104019; else return 105060;
                   } else {
                     if (tick == -6639) return 106110; else return 107171;
                   }
                 } else {
                   if (tick < -6635) {
                     if (tick == -6637) return 108243; else return 109325;
                   } else {
                     if (tick < -6634) {
                       return 110419;
                     } else {
                       if (tick == -6634) return 111523; else return 112638;
                     }
                   }
                 }
               }
             }
           }
         }
       }
     }
   }
  }
}
