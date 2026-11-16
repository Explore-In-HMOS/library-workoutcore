import { SpeedFilterOptions, defaultSpeedFilterOptions } from "../models/SpeedFilterTypes";
import { DistanceSource, DistanceUnit, SourceState } from "../models/TrackingTypes";

export class DefaultSettings {
  minAccuracyMeters: number = 25;
  strideLengthMeters: number = 0.75;
  source: DistanceSource = DistanceSource.STEP;
  autoPause: SourceState = SourceState.OFF;
  unit: DistanceUnit = DistanceUnit.KILOMETER;
  updateInveralsMs: number = 1000;
  poolLengthMeters: number = 25;
  pauseSpeedMps: number = 0.5;
  resumeSpeedMps: number = 0.8;
  pauseDelayMs: number = 5000;
  resumeDelayMs: number = 2000;
  kalman: SourceState = SourceState.OFF;
  kalmanOptions: SpeedFilterOptions = defaultSpeedFilterOptions();
}
