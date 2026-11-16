import { TrackingConfig } from "../../api/TrackingConfig";
import { SourceState } from "../../models/TrackingTypes";
import { GpsTrackCalculator } from "../track/GpsTrackCalculator";
import { ITrackCalculator } from "../track/ITrackCalculator";
import { SpeedFilterFactory } from "../filter/SpeedFilterFactory";
import { SportProfile } from "./SportProfile";

export class RunningProfile implements SportProfile {
  createCalculator(config: TrackingConfig): ITrackCalculator {
    return new GpsTrackCalculator(config.minAccuracyMeters, SpeedFilterFactory.create(config));
  }

  defaults(): TrackingConfig {
    const c: TrackingConfig = new TrackingConfig();
    c.useLocation = SourceState.ON;
    c.useStep = SourceState.OFF;
    c.autoPause = SourceState.ON;
    c.pauseSpeedMps = 0.5;
    c.resumeSpeedMps = 0.8;
    c.pauseDelayMs = 5000;
    c.resumeDelayMs = 2000;
    c.kalman = SourceState.ON;
    return c;
  }
}
