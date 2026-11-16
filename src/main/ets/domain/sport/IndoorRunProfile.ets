import { TrackingConfig } from "../../api/TrackingConfig";
import { SourceState } from "../../models/TrackingTypes";
import { ITrackCalculator } from "../track/ITrackCalculator";
import { StepTrackCalculator } from "../track/StepTrackCalculator";
import { SportProfile } from "./SportProfile";

export class IndoorRunProfile implements SportProfile {
  createCalculator(config: TrackingConfig): ITrackCalculator {
    return new StepTrackCalculator(config.strideLengthMeters);
  }

  defaults(): TrackingConfig {
    const c: TrackingConfig = new TrackingConfig();
    c.useLocation = SourceState.OFF;
    c.useStep = SourceState.ON;
    c.strideLengthMeters = 0.75;
    return c;
  }
}
