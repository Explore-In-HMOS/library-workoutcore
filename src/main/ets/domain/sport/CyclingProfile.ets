import { TrackingConfig } from "../../api/TrackingConfig";
import { SourceState } from "../../models/TrackingTypes";
import { SpeedFilterOptions, defaultSpeedFilterOptions } from "../../models/SpeedFilterTypes";
import { GpsTrackCalculator } from "../track/GpsTrackCalculator";
import { ITrackCalculator } from "../track/ITrackCalculator";
import { SpeedFilterFactory } from "../filter/SpeedFilterFactory";
import { SportProfile } from "./SportProfile";

export class CyclingProfile implements SportProfile {
  createCalculator(config: TrackingConfig): ITrackCalculator {
    return new GpsTrackCalculator(config.minAccuracyMeters, SpeedFilterFactory.create(config));
  }

  defaults(): TrackingConfig {
    const c: TrackingConfig = new TrackingConfig();
    c.useLocation = SourceState.ON;
    c.useStep = SourceState.OFF;
    c.autoPause = SourceState.ON;
    c.pauseSpeedMps = 1.0;
    c.resumeSpeedMps = 1.5;
    c.pauseDelayMs = 5000;
    c.resumeDelayMs = 2000;
    c.kalman = SourceState.ON;

    const filter: SpeedFilterOptions = defaultSpeedFilterOptions();
    filter.maxSpeedMps = 25.0;
    filter.maxAccelMps2 = 4.0;
    filter.zeroSpeedThresholdMps = 0.5;
    c.kalmanOptions = filter;
    return c;
  }
}
