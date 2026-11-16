import { TrackingConfig } from '../../api/TrackingConfig';
import { SourceState } from '../../models/TrackingTypes';
import { SpeedFilterOptions, defaultSpeedFilterOptions } from '../../models/SpeedFilterTypes';
import { ISpeedFilterStrategy } from './ISpeedFilterStrategy';
import { KalmanSpeedFilter } from './KalmanFilter';
import { PassThroughSpeedFilter } from './PassThroughFilter';

/**
 * config.kalman = ON  -> KalmanSpeedFilter (default)
 * config.kalman = OFF -> PassThroughSpeedFilter (cleanup only)
 */
export class SpeedFilterFactory {
  static create(config: TrackingConfig): ISpeedFilterStrategy {
    const options: SpeedFilterOptions = config.kalmanOptions !== undefined
      ? config.kalmanOptions : defaultSpeedFilterOptions();

    return config.kalman === SourceState.ON
      ? new KalmanSpeedFilter(options)
      : new PassThroughSpeedFilter(options);
  }
}
