import { LowPassFilter } from '../filter/LowPassFilter';
import { SignalStats } from './SignalStats';
import { Logger } from '../../util/Logger';

class AxisChannel {
  private smooth: LowPassFilter;
  private base: LowPassFilter;
  private energy: LowPassFilter;
  value: number = 0;
  power: number = 0;

  constructor(sampleRateHz: number) {
    this.smooth = new LowPassFilter(1.0, sampleRateHz);
    this.base = new LowPassFilter(0.1, sampleRateHz);
    this.energy = new LowPassFilter(0.2, sampleRateHz);
  }

  update(v: number): void {
    this.value = this.smooth.filter(v) - this.base.filter(v);
    this.power = this.energy.filter(this.value * this.value);
  }

  reset(): void {
    this.smooth.reset();
    this.base.reset();
    this.energy.reset();
    this.value = 0;
    this.power = 0;
  }
}

export class StrokeDetector {
  private axes: AxisChannel[];
  private activeAxis: number = 0;
  private threshold: number;
  private minIntervalMs: number;

  private armed: boolean = false;
  private lastStrokeTime: number = 0;
  private count: number = 0;

  private stats: SignalStats = new SignalStats();
  private log: Logger = new Logger('StrokeDetector');
  private cycleMax: number = -Number.MAX_VALUE;
  private cycleMin: number = Number.MAX_VALUE;
  private highs: number[] = [];
  private lows: number[] = [];
  private intervals: number[] = [];

  constructor(sampleRateHz: number, threshold: number, minIntervalMs: number) {
    this.axes = [
      new AxisChannel(sampleRateHz),
      new AxisChannel(sampleRateHz),
      new AxisChannel(sampleRateHz)
    ];
    this.threshold = threshold;
    this.minIntervalMs = minIntervalMs;
  }

  onSample(x: number, y: number, z: number, timeMs: number): void {
    this.axes[0].update(x);
    this.axes[1].update(y);
    this.axes[2].update(z);
    this.selectAxis();

    const signal: number = this.axes[this.activeAxis].value;

    this.stats.add(signal);
    if (signal > this.cycleMax) {
      this.cycleMax = signal;
    }
    if (signal < this.cycleMin) {
      this.cycleMin = signal;
    }

    if (!this.armed && signal > this.threshold) {
      this.armed = true;
    } else if (this.armed && signal < -this.threshold) {
      this.armed = false;

      if (timeMs - this.lastStrokeTime >= this.minIntervalMs) {
        const gap: number = this.lastStrokeTime > 0 ? timeMs - this.lastStrokeTime : 0;
        this.count++;
        this.lastStrokeTime = timeMs;

        this.highs.push(this.cycleMax);
        this.lows.push(this.cycleMin);
        if (gap > 0) {
          this.intervals.push(gap);
        }

        const axisName: string = this.activeAxis === 0 ? 'X' : (this.activeAxis === 1 ? 'Y' : 'Z');
        this.log.d(`stroke #${this.count}  axis: ${axisName}  interval: ${gap}ms  peak: ${this.cycleMax.toFixed(2)}  trough: ${this.cycleMin.toFixed(2)}`);

        this.cycleMax = -Number.MAX_VALUE;
        this.cycleMin = Number.MAX_VALUE;
      }
    }
  }

  strokeCount(): number {
    return this.count;
  }

  debugReport(): void {
    const medHigh: number = this.median(this.highs);
    const medLow: number = this.median(this.lows);
    const medGap: number = this.median(this.intervals);

    let minGap: number = 0;
    for (const g of this.intervals) {
      if (minGap === 0 || g < minGap) {
        minGap = g;
      }
    }

    this.log.i('===== REPORT =====');
    this.log.i(`signal  ${this.stats.summary()}`);
    this.log.i(`stroke count: ${this.count}`);
    this.log.i(`typical peak: ${medHigh.toFixed(2)}  typical trough: ${medLow.toFixed(2)}`);
    this.log.i(`typical interval: ${medGap}ms  shortest interval: ${minGap}ms`);
    this.log.i(`recommended high threshold: ${(medHigh * 0.5).toFixed(2)}  low threshold: ${(medLow * 0.5).toFixed(2)}`);
    this.log.i('==================');
  }

  reset(): void {
    for (const a of this.axes) {
      a.reset();
    }
    this.activeAxis = 0;
    this.armed = false;
    this.lastStrokeTime = 0;
    this.count = 0;

    this.stats.reset();
    this.cycleMax = -Number.MAX_VALUE;
    this.cycleMin = Number.MAX_VALUE;
    this.highs = [];
    this.lows = [];
    this.intervals = [];
  }

  private selectAxis(): void {
    let best: number = this.activeAxis;
    for (let i = 0; i < 3; i++) {
      if (this.axes[i].power > this.axes[best].power) {
        best = i;
      }
    }
    if (best !== this.activeAxis
      && this.axes[best].power > this.axes[this.activeAxis].power * 1.3) {
      this.activeAxis = best;
    }
  }

  private median(values: number[]): number {
    if (values.length === 0) {
      return 0;
    }
    const sorted: number[] = values.slice().sort((a: number, b: number) => a - b);
    return sorted[Math.floor(sorted.length / 2)];
  }
}