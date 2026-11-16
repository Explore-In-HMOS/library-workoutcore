import { FilteredSpeedResult, SpeedFilterOptions } from '../../models/SpeedFilterTypes';

/**
 * Instantaneous speed filter. dt is supplied by the caller in seconds so the
 * strategy does not assume a time unit (see GpsTrackCalculator).
 */
export interface ISpeedFilterStrategy {
  reset(): void;
  updateOptions(options: SpeedFilterOptions): void;
  process(rawSpeedMps: number, accuracyMeters: number, dtSeconds: number): FilteredSpeedResult;
}
