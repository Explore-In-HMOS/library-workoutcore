class Sample {
  t: number;
  p: number;
  constructor(t: number, p: number) {
    this.t = t;
    this.p = p;
  }
}

export class LapCounter {
  private poolLength: number;
  private minLapSec: number;
  private maxLapSec: number;
  private minTransSec: number;

  private inSwim: boolean = false;
  private blockStart: number = 0;
  private transCand: number = -1;
  private laps: number = 0;
  private isFirstBlock: boolean = true;
  private lastT: number = 0;
  private searchedUntil: number = -1;
  private buf: Sample[] = [];

  constructor(poolLengthMeters: number) {
    this.poolLength = poolLengthMeters;
    const k: number = poolLengthMeters / 50;
    this.minLapSec = 12 * k;
    this.maxLapSec = 60 * k;
    this.minTransSec = 3;
  }

  setThresholds(minLapSec: number, maxLapSec: number, minTransSec: number): void {
    this.minLapSec = minLapSec;
    this.maxLapSec = maxLapSec;
    this.minTransSec = minTransSec;
  }

  onProbability(p: number, tMs: number): void {
    const t: number = tMs / 1000;
    this.lastT = t;

    if (p >= 0.5) {
      if (this.transCand < 0) {
        this.transCand = t;
      } else if (t - this.transCand >= this.minTransSec && this.inSwim) {
        this.closeBlock(this.transCand, false);
      }
    } else {
      this.transCand = -1;
      if (!this.inSwim) {
        this.inSwim = true;
        this.blockStart = t;
        this.buf = [];
        this.searchedUntil = -1;
      }
    }

    if (this.inSwim) {
      this.buf.push(new Sample(t, p));
      if (this.buf.length > 600) {
        this.buf.shift();
      }
      if (t - this.blockStart > this.maxLapSec && t > this.searchedUntil) {
        if (!this.splitLongBlock()) {
          this.searchedUntil = t + 5;
        }
      }
    }
  }

  finish(): void {
    if (this.inSwim) {
      this.closeBlock(this.lastT, true);
    }
  }

  lapCount(): number {
    return this.laps;
  }

  distanceMeters(): number {
    return this.laps * this.poolLength;
  }

  reset(): void {
    this.inSwim = false;
    this.transCand = -1;
    this.laps = 0;
    this.isFirstBlock = true;
    this.searchedUntil = -1;
    this.buf = [];
  }

  private closeBlock(endT: number, isLast: boolean): void {
    const dur: number = endT - this.blockStart;
    const edge: boolean = this.isFirstBlock || isLast;
    const need: number = edge ? this.minLapSec * 0.5 : this.minLapSec;
    if (dur >= need) {
      this.laps++;
    }
    this.isFirstBlock = false;
    this.inSwim = false;
    this.buf = [];
    this.searchedUntil = -1;
  }

  private splitLongBlock(): boolean {
    const tps: number[] = [0.5, 0.45, 0.4, 0.35, 0.3, 0.25];
    const tts: number[] = [3, 2.5, 2, 1.5, 1, 0.5];
    const pairs: number[][] = [];
    for (const tp of tps) {
      for (const tt of tts) {
        pairs.push([tp, tt]);
      }
    }
    pairs.sort((a: number[], b: number[]) => b[0] * b[1] - a[0] * a[1]);

    for (const pr of pairs) {
      const tp: number = pr[0];
      const tt: number = pr[1];
      let bestStart: number = -1;
      let bestEnd: number = -1;
      let bestMean: number = -1;
      let i: number = 0;
      while (i < this.buf.length) {
        if (this.buf[i].p >= tp) {
          let j: number = i;
          while (j + 1 < this.buf.length && this.buf[j + 1].p >= tp) {
            j++;
          }
          const dur: number = this.buf[j].t - this.buf[i].t;
          if (dur >= tt) {
            let s: number = 0;
            for (let k = i; k <= j; k++) {
              s += this.buf[k].p;
            }
            const mean: number = s / (j - i + 1);
            if (mean > bestMean) {
              bestMean = mean;
              bestStart = i;
              bestEnd = j;
            }
          }
          i = j + 1;
        } else {
          i++;
        }
      }
      if (bestStart >= 0) {
        const splitStart: number = this.buf[bestStart].t;
        const splitEnd: number = this.buf[bestEnd].t;
        const dur: number = splitStart - this.blockStart;
        const need: number = this.isFirstBlock ? this.minLapSec * 0.5 : this.minLapSec;
        if (dur >= need) {
          this.laps++;
        }
        this.isFirstBlock = false;
        this.blockStart = splitEnd;
        const rest: Sample[] = [];
        for (let k = bestEnd; k < this.buf.length; k++) {
          rest.push(this.buf[k]);
        }
        this.buf = rest;
        this.searchedUntil = -1;
        return true;
      }
    }
    return false;
  }
}