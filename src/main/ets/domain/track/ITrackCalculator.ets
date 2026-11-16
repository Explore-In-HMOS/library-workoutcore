import { TrackPoint } from '../../models/TrackingListener';

/**
 * Turns the raw stream of a sport (GPS fixes or pedometer counts) into session metrics.
 * totalMeters()     : accumulated distance, frozen while paused
 * currentSpeedMps() : current speed, independent of pause state (auto-resume depends on it)
 */
export interface ITrackCalculator {
  onLocation(point: TrackPoint): void;
  onStep(count: number): void;
  totalMeters(): number;
  currentSpeedMps(): number;
  pause(): void;
  resume(): void;
  reset(): void;
}
