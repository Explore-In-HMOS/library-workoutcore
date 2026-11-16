import { AutoPauseOptions, PauseState } from '../../models/AutoPauseTypes';

export class GpsAutoPause {
  private opt: AutoPauseOptions;
  private current: PauseState = PauseState.ACTIVE;
  private slowSinceMs: number = -1;
  private fastSinceMs: number = -1;
  private lastSampleMs: number = -1;

  constructor(options: AutoPauseOptions) {
    this.opt = options;
  }

  state(): PauseState {
    return this.current;
  }

  isPaused(): boolean {
    return this.current !== PauseState.ACTIVE;
  }

  /**
   * Processes a new GPS speed sample and returns the state following the sample.
   * Invalid or poor-quality samples are silently ignored; the state remains unchanged.
   */
  onSpeed(speedMps: number, accuracyM: number, tMs: number): PauseState {
    // geoLocationManager returns a negative value when speed cannot be determined.
    // Treating this as "stopped" generates a false pause; ignore it.
    if (!Number.isFinite(speedMps) || speedMps < 0) {
      return this.current;
    }

    if (accuracyM > this.opt.minGpsAccuracyM) {
      return this.current;
    }

    // Manual pausing completely disables the automatic logic.
    if (this.current === PauseState.MANUAL_PAUSED) {
      this.lastSampleMs = tMs;
      return this.current;
    }

    // Time spent in GPS space is not counted as evidence, dwell counters are reset.
    if (this.lastSampleMs >= 0 && tMs - this.lastSampleMs > this.opt.maxPointAgeMs) {
      this.slowSinceMs = -1;
      this.fastSinceMs = -1;
    }
    this.lastSampleMs = tMs;

    if (speedMps < this.opt.pauseSpeedMps) {
      this.fastSinceMs = -1;
      if (this.slowSinceMs < 0) {
        this.slowSinceMs = tMs;
      }
      if (this.current === PauseState.ACTIVE &&
        tMs - this.slowSinceMs >= this.opt.pauseDelayMs) {
        this.current = PauseState.AUTO_PAUSED;
        this.slowSinceMs = -1;
      }
      return this.current;
    }

    if (speedMps > this.opt.resumeSpeedMps) {
      this.slowSinceMs = -1;
      if (this.fastSinceMs < 0) {
        this.fastSinceMs = tMs;
      }
      if (this.current === PauseState.AUTO_PAUSED &&
        tMs - this.fastSinceMs >= this.opt.resumeDelayMs) {
        this.current = PauseState.ACTIVE;
        this.fastSinceMs = -1;
      }
      return this.current;
    }

    this.slowSinceMs = -1;
    this.fastSinceMs = -1;
    return this.current;
  }

  manualPause(): void {
    this.current = PauseState.MANUAL_PAUSED;
    this.slowSinceMs = -1;
    this.fastSinceMs = -1;
  }

  manualResume(): void {
    if (this.current !== PauseState.MANUAL_PAUSED) {
      return;
    }
    this.current = PauseState.ACTIVE;
    this.slowSinceMs = -1;
    this.fastSinceMs = -1;
    this.lastSampleMs = -1;
  }

  reset(): void {
    this.current = PauseState.ACTIVE;
    this.slowSinceMs = -1;
    this.fastSinceMs = -1;
    this.lastSampleMs = -1;
  }
}
