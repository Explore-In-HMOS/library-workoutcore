import { ITrackCalculator } from './ITrackCalculator';
import { TrackPoint } from '../../models/TrackingListener';
import { distanceMeters } from '../GeoMath';
import { ISpeedFilterStrategy } from '../filter/ISpeedFilterStrategy';

/** Fixes slower than this are not added to the distance (standing-still jitter). */
const MIN_MOVE_SPEED_MPS: number = 0.28;

/**
 * Accumulates distance from GPS fixes. The current speed comes from an injected
 * speed filter (Kalman or pass-through); without a filter the raw speed is used.
 */
export class GpsTrackCalculator implements ITrackCalculator {
  private minAccuracy: number;
  private speedFilter: ISpeedFilterStrategy | undefined;
  private total: number = 0;
  private speed: number = 0;
  private lastLat: number = 0;
  private lastLon: number = 0;
  private hasLast: boolean = false;
  private lastLocationMs: number = -1;
  private paused: boolean = false;

  constructor(minAccuracy: number, speedFilter?: ISpeedFilterStrategy) {
    this.minAccuracy = minAccuracy;
    this.speedFilter = speedFilter;
  }

  onLocation(point: TrackPoint): void {
    // Invalid or unreliable fix: used for neither speed nor distance.
    if (!Number.isFinite(point.speed) || point.speed < 0 || point.accuracy > this.minAccuracy) {
      return;
    }

    // The speed filter is fed regardless of pause state: auto-resume decides on
    // the filtered speed, so pausing it would make resuming impossible.
    this.updateSpeed(point);

    if (this.paused) {
      return;
    }

    if (point.speed < MIN_MOVE_SPEED_MPS) {
      return;
    }

    if (!this.hasLast) {
      this.lastLat = point.latitude;
      this.lastLon = point.longitude;
      this.hasLast = true;
      return;
    }

    const d: number = distanceMeters(this.lastLat, this.lastLon, point.latitude, point.longitude);
    this.total += d;
    this.lastLat = point.latitude;
    this.lastLon = point.longitude;
  }

  onStep(count: number): void {
  }

  /**
   * Current speed, independent of pause. Pausing only stops distance accumulation;
   * the emitted TrackingUpdate speed is already zeroed by the client.
   */
  currentSpeedMps(): number {
    return this.speed;
  }

  totalMeters(): number {
    return this.total;
  }

  pause(): void {
    this.paused = true;
  }

  resume(): void {
    this.paused = false;
    this.hasLast = false;
  }

  reset(): void {
    this.total = 0;
    this.speed = 0;
    this.hasLast = false;
    this.paused = false;
    this.lastLocationMs = -1;
    if (this.speedFilter !== undefined) {
      this.speedFilter.reset();
    }
  }

  private updateSpeed(point: TrackPoint): void {
    const now: number = Date.now();

    if (this.speedFilter === undefined) {
      this.speed = point.speed;
      this.lastLocationMs = now;
      return;
    }

    const dtSeconds: number = this.lastLocationMs < 0 ? 0 : (now - this.lastLocationMs) / 1000;
    this.lastLocationMs = now;
    this.speed = this.speedFilter.process(point.speed, point.accuracy, dtSeconds).speedMps;
  }
}
