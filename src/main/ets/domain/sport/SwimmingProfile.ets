import { TrackingConfig } from "../../api/TrackingConfig";
import { SourceState } from "../../models/TrackingTypes";
import { GpsTrackCalculator } from "../track/GpsTrackCalculator";
import { ITrackCalculator } from "../track/ITrackCalculator";
import { SpeedFilterFactory } from "../filter/SpeedFilterFactory";
import { SportProfile } from "./SportProfile";

export class SwimmingProfile implements SportProfile {
  createCalculator(config: TrackingConfig): ITrackCalculator {
    return new GpsTrackCalculator(config.minAccuracyMeters, SpeedFilterFactory.create(config));
  }

  defaults(): TrackingConfig {
    const c: TrackingConfig = new TrackingConfig();
    c.useLocation = SourceState.OFF;
    c.useStep = SourceState.OFF;
    c.useMotion = SourceState.ON;
    c.kalman = SourceState.OFF;
    return c;
  }
}
