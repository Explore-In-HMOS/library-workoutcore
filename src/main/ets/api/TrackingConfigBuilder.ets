import { SpeedFilterOptions } from "../models/SpeedFilterTypes";
import { DistanceSource, DistanceUnit, SourceState, SportType } from "../models/TrackingTypes";
import { TrackingConfig } from "./TrackingConfig";

const MIN_ACCURACY_METERS: number = 0.1;
const MAX_ACCURACY_METERS: number = 1000;
const MIN_STRIDE_METERS: number = 0.2;
const MAX_STRIDE_METERS: number = 1.5;
const MIN_POOL_METERS: number = 10;
const MAX_POOL_METERS: number = 100;
const MIN_UPDATE_INTERVAL_MS: number = 200;
const MAX_UPDATE_INTERVAL_MS: number = 10000;

export class TrackingConfigBuilder {
  private draft: TrackingConfig = new TrackingConfig();

  constructor(sport?: SportType) {
    if (sport !== undefined) {
      this.draft.sport = sport;
    }
  }

  minAccuracy(accuracy: number): TrackingConfigBuilder {
    if (!Number.isFinite(accuracy) || accuracy < MIN_ACCURACY_METERS ||
      accuracy > MAX_ACCURACY_METERS) {
      throw new Error(`minAccuracy must be between ${MIN_ACCURACY_METERS} and ${MAX_ACCURACY_METERS} metres`);
    }
    this.draft.minAccuracyMeters = accuracy;
    return this;
  }

  unit(unit: DistanceUnit): TrackingConfigBuilder {
    this.draft.unit = unit;
    return this;
  }

  source(source: DistanceSource): TrackingConfigBuilder {
    this.draft.source = source;
    return this;
  }

  autoPause(enabled: boolean): TrackingConfigBuilder {
    this.draft.autoPause = enabled ? SourceState.ON : SourceState.OFF;
    return this;
  }

  pauseSpeed(mps: number): TrackingConfigBuilder {
    if (!Number.isFinite(mps) || mps < 0) {
      throw new Error('pauseSpeed must be zero or greater');
    }
    this.draft.pauseSpeedMps = mps;
    return this;
  }

  resumeSpeed(mps: number): TrackingConfigBuilder {
    if (!Number.isFinite(mps) || mps < 0) {
      throw new Error('resumeSpeed must be zero or greater');
    }
    this.draft.resumeSpeedMps = mps;
    return this;
  }

  pauseDelay(ms: number): TrackingConfigBuilder {
    if (!Number.isFinite(ms) || ms < 0) {
      throw new Error('pauseDelay must be zero or greater');
    }
    this.draft.pauseDelayMs = ms;
    return this;
  }

  resumeDelay(ms: number): TrackingConfigBuilder {
    if (!Number.isFinite(ms) || ms < 0) {
      throw new Error('resumeDelay must be zero or greater');
    }
    this.draft.resumeDelayMs = ms;
    return this;
  }

  useLocation(enabled: boolean): TrackingConfigBuilder {
    this.draft.useLocation = enabled ? SourceState.ON : SourceState.OFF;
    return this;
  }

  useStep(enabled: boolean): TrackingConfigBuilder {
    this.draft.useStep = enabled ? SourceState.ON : SourceState.OFF;
    return this;
  }

  useSteps(enabled: boolean): TrackingConfigBuilder {
    return this.useStep(enabled);
  }

  useMotion(enabled: boolean): TrackingConfigBuilder {
    this.draft.useMotion = enabled ? SourceState.ON : SourceState.OFF;
    return this;
  }

  strideLength(meters: number): TrackingConfigBuilder {
    if (!Number.isFinite(meters) || meters < MIN_STRIDE_METERS || meters > MAX_STRIDE_METERS) {
      throw new Error(`strideLength must be between ${MIN_STRIDE_METERS} and ${MAX_STRIDE_METERS} metres`);
    }
    this.draft.strideLengthMeters = meters;
    return this;
  }

  poolLength(meters: number): TrackingConfigBuilder {
    if (!Number.isFinite(meters) || meters < MIN_POOL_METERS || meters > MAX_POOL_METERS) {
      throw new Error(`poolLength must be between ${MIN_POOL_METERS} and ${MAX_POOL_METERS} metres`);
    }
    this.draft.poolLengthMeters = meters;
    return this;
  }

  sport(value: SportType): TrackingConfigBuilder {
    this.draft.sport = value;
    return this;
  }

  updateInterval(ms: number): TrackingConfigBuilder {
    if (!Number.isFinite(ms) || ms < MIN_UPDATE_INTERVAL_MS || ms > MAX_UPDATE_INTERVAL_MS) {
      throw new Error(`updateInterval must be between ${MIN_UPDATE_INTERVAL_MS} and ${MAX_UPDATE_INTERVAL_MS} ms`);
    }
    this.draft.updateInveralsMs = ms;
    return this;
  }

  intervals(ms: number): TrackingConfigBuilder {
    return this.updateInterval(ms);
  }

  kalman(enabled: boolean): TrackingConfigBuilder {
    this.draft.kalman = enabled ? SourceState.ON : SourceState.OFF;
    return this;
  }

  kalmanOptions(options: SpeedFilterOptions): TrackingConfigBuilder {
    this.draft.kalmanOptions = options;
    return this;
  }

  static walking(): TrackingConfigBuilder {
    const builder: TrackingConfigBuilder = new TrackingConfigBuilder(SportType.WALKING);
    builder.source(DistanceSource.GPS);
    builder.minAccuracy(30);
    return builder;
  }

  build(): TrackingConfig {
    if (this.allSourcesOff()) {
      throw new Error('At least one of location, steps or motion must be enabled');
    }
    return this.draft.clone();
  }

  private allSourcesOff(): boolean {
    return this.draft.useLocation === SourceState.OFF &&
      this.draft.useStep === SourceState.OFF &&
      this.draft.useMotion === SourceState.OFF;
  }
}
