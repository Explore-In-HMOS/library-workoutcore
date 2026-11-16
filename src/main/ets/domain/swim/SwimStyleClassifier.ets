import { Logger } from '../../util/Logger';

export enum SwimStyle {
  FREESTYLE = 0,
  BREASTSTROKE = 1,
  BACKSTROKE = 2,
  BUTTERFLY = 3,
  TRANSITION = 4,
  UNKNOWN = -1
}

export class SwimStyleClassifier {
  private static readonly WINDOW_SEC: number = 3.0;
  private static readonly STEP_SEC: number = 1.5;
  private static readonly VOTE_SIZE: number = 5;

  private sampleRateHz: number;
  private windowSize: number;
  private stepSize: number;
  private buf: number[][] = [[], [], [], [], [], []];
  private sinceLast: number = 0;
  private votes: number[] = [];
  private style: SwimStyle = SwimStyle.UNKNOWN;
  private log: Logger = new Logger('SwimStyleClassifier');

  constructor(sampleRateHz: number) {
    this.sampleRateHz = sampleRateHz;
    this.windowSize = Math.round(SwimStyleClassifier.WINDOW_SEC * sampleRateHz);
    this.stepSize = Math.round(SwimStyleClassifier.STEP_SEC * sampleRateHz);
  }

  onSample(ax: number, ay: number, az: number, gx: number, gy: number, gz: number): void {
    const v: number[] = [ax, ay, az, gx, gy, gz];
    for (let i = 0; i < 6; i++) {
      this.buf[i].push(v[i]);
      if (this.buf[i].length > this.windowSize) {
        this.buf[i].shift();
      }
    }
    this.sinceLast++;
    if (this.buf[0].length === this.windowSize && this.sinceLast >= this.stepSize) {
      this.sinceLast = 0;
      const f: number[] = this.features();
      const cls: number = SwimStyleClassifier.predict(f);
      this.log.d(`class ${cls}  gyro1_std: ${f[21].toFixed(2)}  accel_std: ${f[31].toFixed(2)}  gyro0_mean: ${f[15].toFixed(2)}`);
      this.votes.push(cls);
      if (this.votes.length > SwimStyleClassifier.VOTE_SIZE) {
        this.votes.shift();
      }
      this.style = SwimStyleClassifier.toStyle(this.majority());
    }
  }

  currentStyle(): SwimStyle {
    return this.style;
  }

  reset(): void {
    this.buf = [[], [], [], [], [], []];
    this.sinceLast = 0;
    this.votes = [];
    this.style = SwimStyle.UNKNOWN;
  }

  features(): number[] {
    const f: number[] = [];
    for (let i = 0; i < 6; i++) {
      const s: number[] = this.buf[i];
      f.push(SwimStyleClassifier.mean(s));
      f.push(SwimStyleClassifier.std(s));
      f.push(SwimStyleClassifier.min(s));
      f.push(SwimStyleClassifier.max(s));
      f.push(this.zcr(s));
    }
    const am: number[] = [];
    const gm: number[] = [];
    for (let k = 0; k < this.windowSize; k++) {
      const a0: number = this.buf[0][k];
      const a1: number = this.buf[1][k];
      const a2: number = this.buf[2][k];
      const g0: number = this.buf[3][k];
      const g1: number = this.buf[4][k];
      const g2: number = this.buf[5][k];
      am.push(Math.sqrt(a0 * a0 + a1 * a1 + a2 * a2));
      gm.push(Math.sqrt(g0 * g0 + g1 * g1 + g2 * g2));
    }
    f.push(SwimStyleClassifier.mean(am));
    f.push(SwimStyleClassifier.std(am));
    f.push(this.zcr(am));
    f.push(SwimStyleClassifier.mean(gm));
    f.push(SwimStyleClassifier.std(gm));
    return f;
  }

  static predict(f: number[]): number {
    if (f[21] <= 1.924530267715454) {
      if (f[31] <= 3.1336874961853027) {
        if (f[26] <= 1.8806633353233337) {
          if (f[27] <= -5.5885703563690186) {
            if (f[10] <= 5.300014972686768) {
              return 4;
            } else {
              return 1;
            }
          } else {
            if (f[15] <= 0.2101724073290825) {
              if (f[30] <= 10.20476770401001) {
                return 4;
              } else {
                return 4;
              }
            } else {
              if (f[10] <= 8.048670291900635) {
                return 4;
              } else {
                return 4;
              }
            }
          }
        } else {
          if (f[15] <= 0.04977162554860115) {
            if (f[7] <= -16.61377239227295) {
              return 4;
            } else {
              if (f[3] <= 2.6439415216445923) {
                return 4;
              } else {
                return 4;
              }
            }
          } else {
            if (f[28] <= 3.3020050525665283) {
              if (f[22] <= -1.3566505312919617) {
                return 1;
              } else {
                return 1;
              }
            } else {
              if (f[7] <= -14.691262245178223) {
                return 4;
              } else {
                return 4;
              }
            }
          }
        }
      } else {
        if (f[13] <= 10.986879825592041) {
          if (f[15] <= 1.2371853590011597) {
            if (f[10] <= 3.317762613296509) {
              if (f[5] <= -6.752529144287109) {
                return 4;
              } else {
                return 4;
              }
            } else {
              if (f[33] <= 2.8189539909362793) {
                return 4;
              } else {
                return 1;
              }
            }
          } else {
            return 2;
          }
        } else {
          if (f[34] <= 1.6963990330696106) {
            if (f[10] <= 0.8247974514961243) {
              return 2;
            } else {
              if (f[27] <= -4.465338468551636) {
                return 1;
              } else {
                return 4;
              }
            }
          } else {
            if (f[15] <= -0.6515858173370361) {
              if (f[26] <= 2.819005250930786) {
                return 4;
              } else {
                return 0;
              }
            } else {
              if (f[17] <= -11.542328834533691) {
                return 4;
              } else {
                return 1;
              }
            }
          }
        }
      }
    } else {
      if (f[15] <= -0.07320931926369667) {
        if (f[30] <= 16.633769989013672) {
          if (f[16] <= 4.308368921279907) {
            if (f[33] <= 2.8955708742141724) {
              if (f[33] <= 2.6165748834609985) {
                return 4;
              } else {
                return 4;
              }
            } else {
              if (f[10] <= -0.4050520956516266) {
                return 4;
              } else {
                return 0;
              }
            }
          } else {
            if (f[27] <= -8.308619976043701) {
              if (f[25] <= -0.4069587290287018) {
                return 3;
              } else {
                return 3;
              }
            } else {
              if (f[30] <= 13.757823944091797) {
                return 0;
              } else {
                return 0;
              }
            }
          }
        } else {
          if (f[8] <= 32.8210334777832) {
            if (f[16] <= 4.448521852493286) {
              if (f[5] <= 0.853642612695694) {
                return 0;
              } else {
                return 3;
              }
            } else {
              if (f[23] <= 11.369362831115723) {
                return 3;
              } else {
                return 0;
              }
            }
          } else {
            if (f[22] <= -5.157375812530518) {
              if (f[23] <= 15.040563106536865) {
                return 3;
              } else {
                return 0;
              }
            } else {
              if (f[18] <= 9.490391254425049) {
                return 0;
              } else {
                return 0;
              }
            }
          }
        }
      } else {
        if (f[5] <= -1.6140469908714294) {
          if (f[33] <= 3.0204144716262817) {
            return 4;
          } else {
            if (f[12] <= -8.355514526367188) {
              if (f[1] <= 7.843615770339966) {
                return 2;
              } else {
                return 2;
              }
            } else {
              return 2;
            }
          }
        } else {
          if (f[0] <= 4.956254243850708) {
            if (f[11] <= 8.655021667480469) {
              if (f[0] <= -4.915029525756836) {
                return 1;
              } else {
                return 4;
              }
            } else {
              return 2;
            }
          } else {
            if (f[12] <= -11.185224056243896) {
              return 0;
            } else {
              return 0;
            }
          }
        }
      }
    }
  }

  private static toStyle(n: number): SwimStyle {
    switch (n) {
      case 0: return SwimStyle.FREESTYLE;
      case 1: return SwimStyle.BREASTSTROKE;
      case 2: return SwimStyle.BACKSTROKE;
      case 3: return SwimStyle.BUTTERFLY;
      case 4: return SwimStyle.TRANSITION;
      default: return SwimStyle.UNKNOWN;
    }
  }

  private majority(): number {
    const c: number[] = [0, 0, 0, 0, 0];
    for (const v of this.votes) {
      c[v]++;
    }
    let best: number = 0;
    for (let i = 1; i < 5; i++) {
      if (c[i] > c[best]) {
        best = i;
      }
    }
    return best;
  }

  private static mean(s: number[]): number {
    let t: number = 0;
    for (const v of s) {
      t += v;
    }
    return t / s.length;
  }

  private static std(s: number[]): number {
    const m: number = SwimStyleClassifier.mean(s);
    let t: number = 0;
    for (const v of s) {
      t += (v - m) * (v - m);
    }
    return Math.sqrt(t / s.length);
  }

  private static min(s: number[]): number {
    let r: number = s[0];
    for (const v of s) {
      if (v < r) {
        r = v;
      }
    }
    return r;
  }

  private static max(s: number[]): number {
    let r: number = s[0];
    for (const v of s) {
      if (v > r) {
        r = v;
      }
    }
    return r;
  }

  private zcr(s: number[]): number {
    const m: number = SwimStyleClassifier.mean(s);
    let c: number = 0;
    for (let k = 1; k < s.length; k++) {
      if ((s[k - 1] - m < 0) !== (s[k] - m < 0)) {
        c++;
      }
    }
    return c / (s.length / this.sampleRateHz);
  }
}
