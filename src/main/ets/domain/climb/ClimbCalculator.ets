import { ClimbData, ClimbOptions } from '../../models/ClimbTypes';

const MEDIAN_WINDOW: number = 5;
const ACCEL_WINDOW: number = 50;


export class ClimbCalculator {
  private opt: ClimbOptions;


  private buffer: number[] = [];
  private refPressure: number = 0;
  private smoothed: number = 0;
  private smoothInit: boolean = false;
  private lastMedian: number = 0;
  private rawM: number = 0;
  private filteredM: number = 0;

  private gain: number = 0;
  private loss: number = 0;
  private lastTurn: number = 0;
  private extreme: number = 0;
  private direction: number = 0;

  private accelBuffer: number[] = [];
  private motionSd: number = 0;
  private moving: boolean = true;

  private paused: boolean = false;

  private recording: string[] = [];
  private recordingOn: boolean = false;

  constructor(options: ClimbOptions) {
    this.opt = options;
  }

  onPressure(pressureHpa: number): void {
    if (pressureHpa <= 0 || !Number.isFinite(pressureHpa)) {
      return;
    }
    if (this.recordingOn) {
      this.recording.push(
        `${Date.now()},${pressureHpa.toFixed(3)},${this.motionSd.toFixed(4)}`);
    }

    const med: number = this.median(pressureHpa);
    this.lastMedian = med;


    if (this.buffer.length < MEDIAN_WINDOW) {
      return;
    }
    if (this.refPressure === 0) {
      this.refPressure = med;
      return;
    }

    this.rawM = this.metersBetween(pressureHpa, this.refPressure);
    const medMeters: number = this.metersBetween(med, this.refPressure);
    this.filteredM = this.smooth(medMeters);
    this.accumulate(this.filteredM);
  }

  onAccel(x: number, y: number, z: number): void {

    const mag: number = Math.sqrt(x * x + y * y + z * z) - 9.81;
    this.accelBuffer.push(mag);
    if (this.accelBuffer.length > ACCEL_WINDOW) {
      this.accelBuffer.shift();
    }
    if (this.accelBuffer.length < ACCEL_WINDOW) {
      return;
    }

    let sum: number = 0;
    for (let i = 0; i < this.accelBuffer.length; i++) {
      sum = sum + this.accelBuffer[i];
    }
    const mean: number = sum / this.accelBuffer.length;

    let varSum: number = 0;
    for (let i = 0; i < this.accelBuffer.length; i++) {
      const d: number = this.accelBuffer[i] - mean;
      varSum = varSum + d * d;
    }
    this.motionSd = Math.sqrt(varSum / this.accelBuffer.length);
    this.moving = this.motionSd > this.opt.motionThreshold;
  }

  injectMotionSd(sd: number): void {
    this.motionSd = sd;
    this.moving = sd > this.opt.motionThreshold;
  }

  pause(): void {
    this.paused = true;
  }

  resume(): void {
    this.paused = false;
  }

  result(): ClimbData {
    const d: ClimbData = {
      totalGainM: this.displayGain(),
      totalLossM: this.displayLoss(),
      relativeAltitudeM: this.filteredM,
      rawAltitudeM: this.rawM,
      pressureHpa: this.lastMedian,
      moving: this.moving,
      motionSd: this.motionSd,
      ready: this.refPressure !== 0
    };
    return d;
  }

  startRecording(): void {
    this.recording = [];
    this.recordingOn = true;
  }

  stopRecording(): string {
    this.recordingOn = false;
    return this.recording.join('\n');
  }

  reset(): void {
    this.buffer = [];
    this.refPressure = 0;
    this.smoothed = 0;
    this.smoothInit = false;
    this.lastMedian = 0;
    this.rawM = 0;
    this.filteredM = 0;
    this.gain = 0;
    this.loss = 0;
    this.lastTurn = 0;
    this.extreme = 0;
    this.direction = 0;
    this.accelBuffer = [];
    this.motionSd = 0;
    this.moving = true;
    this.paused = false;
  }


  private median(value: number): number {
    this.buffer.push(value);
    if (this.buffer.length > MEDIAN_WINDOW) {
      this.buffer.shift();
    }
    const sorted: number[] = this.buffer.slice();
    sorted.sort((a: number, b: number) => a - b);
    return sorted[Math.floor(sorted.length / 2)];
  }


  private smooth(value: number): number {
    if (!this.smoothInit) {
      this.smoothed = value;
      this.smoothInit = true;
      return this.smoothed;
    }
    this.smoothed = this.smoothed + this.opt.smoothingAlpha * (value - this.smoothed);
    return this.smoothed;
  }


  private metersBetween(p: number, ref: number): number {
    const a: number = 44330.77 * (1 - Math.pow(p / 1013.25, 0.1902632));
    const b: number = 44330.77 * (1 - Math.pow(ref / 1013.25, 0.1902632));
    return a - b;
  }


  private accumulate(h: number): void {
    if (this.paused || !this.moving) {
      this.lastTurn = this.lastTurn + (h - this.extreme);
      this.extreme = h;
      return;
    }

    const t: number = this.opt.turnThresholdM;

    if (this.direction === 0) {
     if (h >= this.lastTurn + t) {
        this.direction = 1;
        this.extreme = h;
      } else if (h <= this.lastTurn - t) {
        this.direction = -1;
        this.extreme = h;
      }
    } else if (this.direction === 1) {
      if (h > this.extreme) {
        this.extreme = h;
      } else if (h <= this.extreme - t) {
        this.gain = this.gain + (this.extreme - this.lastTurn);
        this.lastTurn = this.extreme;
        this.direction = -1;
        this.extreme = h;
      }
    } else {
      if (h < this.extreme) {
        this.extreme = h;
      } else if (h >= this.extreme + t) {
        this.loss = this.loss + (this.lastTurn - this.extreme);
        this.lastTurn = this.extreme;
        this.direction = 1;
        this.extreme = h;
      }
    }
  }


  private displayGain(): number {
    if (this.direction === 1 && this.extreme > this.lastTurn) {
      return this.gain + (this.extreme - this.lastTurn);
    }
    return this.gain;
  }

  private displayLoss(): number {
    if (this.direction === -1 && this.extreme < this.lastTurn) {
      return this.loss + (this.lastTurn - this.extreme);
    }
    return this.loss;
  }
}