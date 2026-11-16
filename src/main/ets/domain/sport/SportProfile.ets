import { TrackingConfig } from '../../api/TrackingConfig';
import { ITrackCalculator } from '../track/ITrackCalculator';

export interface SportProfile {
  defaults(): TrackingConfig;
  createCalculator(config: TrackingConfig): ITrackCalculator;
}
