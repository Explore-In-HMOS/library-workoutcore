import { FilteredSpeedResult, SpeedFilterOptions } from '../../models/SpeedFilterTypes';
import { ISpeedFilterStrategy } from './ISpeedFilterStrategy';

/** If the GPS gap is longer than this, restart instead of predicting through it. */
const MAX_GAP_SECONDS: number = 10.0;

/**
 * Two-state [v, a] adaptive kinematic Kalman filter.
 * Measurement noise (R) scales with the square of GPS accuracy; jumps larger
 * than physically possible within dt are suppressed unless the sample agrees.
 */
export class KalmanSpeedFilter implements ISpeedFilterStrategy {
  private options: SpeedFilterOptions;
  private initialized: boolean = false;

  private v: number = 0.0;
  private a: number = 0.0;

  private p00: number = 1.0;
  private p01: number = 0.0;
  private p10: number = 0.0;
  private p11: number = 1.0;

  private last: FilteredSpeedResult = {
    speedMps: 0.0,
    rawSpeedMps: 0.0,
    estimatedAccelMps2: 0.0,
    isKalmanActive: true,
    isSpikeClamped: false
  };

  constructor(options: SpeedFilterOptions) {
    this.options = options;
  }

  public reset(): void {
    this.initialized = false;
    this.v = 0.0;
    this.a = 0.0;
    this.p00 = 1.0;
    this.p01 = 0.0;
    this.p10 = 0.0;
    this.p11 = 1.0;
    this.last = this.build(0.0, 0.0, 0.0, false);
  }

  public updateOptions(options: SpeedFilterOptions): void {
    this.options = options;
  }

  public process(rawSpeedMps: number, accuracyMeters: number, dtSeconds: number): FilteredSpeedResult {
    // Invalid sample (geoLocationManager returns a negative speed when unknown):
    // ignore it without touching the state.
    if (!Number.isFinite(rawSpeedMps) || rawSpeedMps < 0.0) {
      return this.last;
    }

    const safeSpeed: number = Math.min(this.options.maxSpeedMps, rawSpeedMps);
    const overLimit: boolean = rawSpeedMps > this.options.maxSpeedMps;

    if (!this.initialized) {
      return this.initialize(safeSpeed, rawSpeedMps, overLimit);
    }
    if (!Number.isFinite(dtSeconds) || dtSeconds <= 0.0) {
      return this.last;
    }
    if (dtSeconds > MAX_GAP_SECONDS) {
      return this.initialize(safeSpeed, rawSpeedMps, overLimit);
    }

    const dt: number = dtSeconds;
    const dt2: number = dt * dt;

    // 1. Predict: F = [[1, dt], [0, 1]]
    const dampedA: number = this.a * this.options.accelDamping;
    const vPred: number = Math.max(0.0, this.v + dampedA * dt);
    const p00Pred: number = this.p00 + dt * (this.p10 + this.p01) + dt2 * this.p11 +
      this.options.velocityProcessNoise * dt;
    const p01Pred: number = this.p01 + dt * this.p11;
    const p10Pred: number = this.p10 + dt * this.p11;
    const p11Pred: number = this.p11 + this.options.accelProcessNoise * dt;

    // 2. Adaptive R and physical spike gate
    const accuracy: number = Number.isFinite(accuracyMeters) && accuracyMeters > 0.0
      ? accuracyMeters : this.options.referenceAccuracyMeters;
    const accuracyRatio: number = accuracy / this.options.referenceAccuracyMeters;
    let rAdaptive: number = this.options.measurementNoiseBase * accuracyRatio * accuracyRatio;

    const innovation: number = safeSpeed - vPred;
    const maxDeltaV: number = this.options.maxAccelMps2 * dt;
    let isSpikeClamped: boolean = overLimit;
    if (maxDeltaV > 0.0 && Math.abs(innovation) > maxDeltaV) {
      isSpikeClamped = true;
      const penalty: number = Math.abs(innovation) / maxDeltaV;
      rAdaptive *= penalty * penalty * 4.0;
    }

    // 3. Update: P = (I - K H) P
    const s: number = p00Pred + rAdaptive;
    const kV: number = p00Pred / s;
    const kA: number = p10Pred / s;

    this.v = Math.min(this.options.maxSpeedMps, Math.max(0.0, vPred + kV * innovation));
    this.a = dampedA + kA * innovation;

    this.p00 = (1.0 - kV) * p00Pred;
    this.p01 = (1.0 - kV) * p01Pred;
    this.p10 = p10Pred - kA * p00Pred;
    this.p11 = p11Pred - kA * p01Pred;

    // 4. Zero-speed clamp: lock residual speed to zero while standing still.
    if (this.v < this.options.zeroSpeedThresholdMps &&
      safeSpeed < this.options.zeroSpeedThresholdMps * 1.5) {
      this.v = 0.0;
      this.a = 0.0;
    }

    this.last = this.build(this.v, rawSpeedMps, this.a, isSpikeClamped);
    return this.last;
  }

  private initialize(safeSpeed: number, rawSpeedMps: number, overLimit: boolean): FilteredSpeedResult {
    this.initialized = true;
    this.v = safeSpeed < this.options.zeroSpeedThresholdMps ? 0.0 : safeSpeed;
    this.a = 0.0;
    this.p00 = 1.0;
    this.p01 = 0.0;
    this.p10 = 0.0;
    this.p11 = 1.0;
    this.last = this.build(this.v, rawSpeedMps, 0.0, overLimit);
    return this.last;
  }

  private build(speedMps: number, rawSpeedMps: number, accelMps2: number,
    spikeClamped: boolean): FilteredSpeedResult {
    return {
      speedMps: speedMps,
      rawSpeedMps: rawSpeedMps,
      estimatedAccelMps2: accelMps2,
      isKalmanActive: true,
      isSpikeClamped: spikeClamped
    };
  }
}
