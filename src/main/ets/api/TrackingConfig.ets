import { SpeedFilterOptions } from "../models/SpeedFilterTypes";
import { DistanceSource, DistanceUnit, SourceState, SportType } from "../models/TrackingTypes";

export class TrackingConfig {
  sport: SportType = SportType.RUNNING;
  minAccuracyMeters: number = -1
  strideLengthMeters: number = -1
  source: DistanceSource = DistanceSource.STEP
  autoPause: SourceState = SourceState.UNSET
  unit: DistanceUnit = DistanceUnit.KILOMETER
  updateInveralsMs: number = -1
  useLocation: SourceState = SourceState.UNSET
  useMotion: SourceState = SourceState.UNSET;
  useStep: SourceState = SourceState.UNSET;
  poolLengthMeters: number = -1;
  pauseSpeedMps: number = -1;
  resumeSpeedMps: number = -1;
  pauseDelayMs: number = -1;
  resumeDelayMs: number = -1;
  kalman: SourceState = SourceState.UNSET;
  kalmanOptions?: SpeedFilterOptions;

  clone(): TrackingConfig {
    const copy: TrackingConfig = new TrackingConfig();
    copy.sport = this.sport;
    copy.minAccuracyMeters = this.minAccuracyMeters;
    copy.strideLengthMeters = this.strideLengthMeters;
    copy.source = this.source;
    copy.autoPause = this.autoPause;
    copy.unit = this.unit;
    copy.updateInveralsMs = this.updateInveralsMs;
    copy.useLocation = this.useLocation;
    copy.useMotion = this.useMotion;
    copy.useStep = this.useStep;
    copy.poolLengthMeters = this.poolLengthMeters;
    copy.pauseSpeedMps = this.pauseSpeedMps;
    copy.resumeSpeedMps = this.resumeSpeedMps;
    copy.pauseDelayMs = this.pauseDelayMs;
    copy.resumeDelayMs = this.resumeDelayMs;
    copy.kalman = this.kalman;
    if (this.kalmanOptions !== undefined) {
      const options: SpeedFilterOptions = this.kalmanOptions;
      copy.kalmanOptions = {
        velocityProcessNoise: options.velocityProcessNoise,
        accelProcessNoise: options.accelProcessNoise,
        measurementNoiseBase: options.measurementNoiseBase,
        referenceAccuracyMeters: options.referenceAccuracyMeters,
        maxAccelMps2: options.maxAccelMps2,
        maxSpeedMps: options.maxSpeedMps,
        zeroSpeedThresholdMps: options.zeroSpeedThresholdMps,
        accelDamping: options.accelDamping
      };
    }
    return copy;
  }
}
