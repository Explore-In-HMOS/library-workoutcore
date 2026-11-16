import { ITrackCalculator } from './ITrackCalculator';
import { TrackPoint } from '../../models/TrackingListener';

export class StepTrackCalculator implements ITrackCalculator {
  private strideLength: number;
  private baseSteps: number = -1;
  private steps: number = 0;
  private lastSteps: number = 0;
  private lastTime: number = 0;
  private lastSpeed: number = 0;
  private paused: boolean = false;
  private lastRawCount: number = 0;

  constructor(strideLength: number) {
    this.strideLength = strideLength;
  }

  onLocation(point: TrackPoint): void {
  }

  onStep(count: number): void {
    const now: number = Date.now();
    this.lastRawCount = count;

    if (this.paused) {
      return;
    }

    if (this.baseSteps < 0) {
      this.baseSteps = count;
      this.lastSteps = count;
      this.lastTime = now;
      this.steps = 0;
      return;
    }

    const dt: number = (now - this.lastTime) / 1000;

    if (dt > 0) {
      const newSteps: number = count - this.lastSteps;
      this.lastSpeed = (newSteps * this.strideLength) / dt;
    }

    this.steps = count - this.baseSteps;
    this.lastSteps = count;
    this.lastTime = now;
  }

  currentSpeedMps(): number {
    return this.lastSpeed;
  }

  totalMeters(): number {
    return this.steps * this.strideLength;
  }

  pause(): void {
    this.paused = true;
    this.lastSpeed = 0;
  }

  resume(): void {
    this.paused = false;
    if (this.baseSteps >= 0) {
      // Exclude steps taken during the pause; distance continues from where it stopped.
      this.baseSteps = this.lastRawCount - this.steps;
    }
    this.lastSteps = this.lastRawCount;
    this.lastTime = Date.now();
    this.lastSpeed = 0;
  }

  reset(): void {
    this.baseSteps = -1;
    this.steps = 0;
    this.paused = false;
    this.lastRawCount = 0;
  }
}
