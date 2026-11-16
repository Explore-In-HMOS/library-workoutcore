import { TrackingConfig } from "../../api/TrackingConfig";
import { SourceState } from "../../models/TrackingTypes";
import { GpsTrackCalculator } from "../track/GpsTrackCalculator";
import { ITrackCalculator } from "../track/ITrackCalculator";
import { SpeedFilterFactory } from "../filter/SpeedFilterFactory";
import { SportProfile } from "./SportProfile";

export class WaterSportsProfile implements SportProfile {
  defaults(): TrackingConfig {
    const c: TrackingConfig = new TrackingConfig();
    c.useLocation = SourceState.ON;
    c.useStep = SourceState.OFF;
    c.useMotion = SourceState.OFF;
    return c;
  }

  createCalculator(config: TrackingConfig): ITrackCalculator {
    return new GpsTrackCalculator(config.minAccuracyMeters, SpeedFilterFactory.create(config));
  }
}
