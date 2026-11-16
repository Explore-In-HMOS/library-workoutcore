import { FilteredSpeedResult, SpeedFilterOptions } from '../../models/SpeedFilterTypes';
import { ISpeedFilterStrategy } from './ISpeedFilterStrategy';

/**
 * Lightweight strategy used when Kalman is disabled: no filtering, it only
 * removes negative/invalid speeds and values outside the physical limit.
 */
export class PassThroughSpeedFilter implements ISpeedFilterStrategy {
  private options: SpeedFilterOptions;

  constructor(options: SpeedFilterOptions) {
    this.options = options;
  }

  public reset(): void {
  }

  public updateOptions(options: SpeedFilterOptions): void {
    this.options = options;
  }

  public process(rawSpeedMps: number, _accuracyMeters: number, _dtSeconds: number): FilteredSpeedResult {
    const valid: boolean = Number.isFinite(rawSpeedMps) && rawSpeedMps > 0.0;
    const clampedSpeed: number = valid ? Math.min(this.options.maxSpeedMps, rawSpeedMps) : 0.0;
    const finalSpeed: number = clampedSpeed < this.options.zeroSpeedThresholdMps ? 0.0 : clampedSpeed;

    return {
      speedMps: finalSpeed,
      rawSpeedMps: rawSpeedMps,
      estimatedAccelMps2: 0.0,
      isKalmanActive: false,
      isSpikeClamped: valid && rawSpeedMps > this.options.maxSpeedMps
    };
  }
}
