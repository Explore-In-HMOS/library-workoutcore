import { SpeedFilterOptions } from "../models/SpeedFilterTypes";
import { SourceState } from "../models/TrackingTypes";
import { DefaultSettings } from "./DefaultSettings";
import { TrackingConfig } from "./TrackingConfig";

export class ConfigMerger {
  static merge(profileDefaults: TrackingConfig, userConfig: TrackingConfig): TrackingConfig {
    const fallback: DefaultSettings = new DefaultSettings();
    const result: TrackingConfig = new TrackingConfig();

    result.sport = userConfig.sport;

    result.useLocation = ConfigMerger.pick(
      userConfig.useLocation,
      profileDefaults.useLocation,
      SourceState.OFF
    );

    result.useStep = ConfigMerger.pick(
      userConfig.useStep,
      profileDefaults.useStep,
      SourceState.OFF
    );

    result.useMotion = ConfigMerger.pick(
      userConfig.useMotion,
      profileDefaults.useMotion,
      SourceState.OFF
    );

    result.minAccuracyMeters = ConfigMerger.pick(
      userConfig.minAccuracyMeters,
      profileDefaults.minAccuracyMeters,
      fallback.minAccuracyMeters
    );

    result.poolLengthMeters = ConfigMerger.pick(
      userConfig.poolLengthMeters,
      profileDefaults.poolLengthMeters,
      fallback.poolLengthMeters
    );

    result.strideLengthMeters = ConfigMerger.pick(
      userConfig.strideLengthMeters,
      profileDefaults.strideLengthMeters,
      fallback.strideLengthMeters
    );

    result.updateInveralsMs = ConfigMerger.pick(
      userConfig.updateInveralsMs,
      profileDefaults.updateInveralsMs,
      fallback.updateInveralsMs
    );

    result.autoPause = ConfigMerger.pick(
      userConfig.autoPause,
      profileDefaults.autoPause,
      fallback.autoPause
    );

    result.pauseSpeedMps = ConfigMerger.pick(
      userConfig.pauseSpeedMps,
      profileDefaults.pauseSpeedMps,
      fallback.pauseSpeedMps
    );

    result.resumeSpeedMps = ConfigMerger.pick(
      userConfig.resumeSpeedMps,
      profileDefaults.resumeSpeedMps,
      fallback.resumeSpeedMps
    );

    result.pauseDelayMs = ConfigMerger.pick(
      userConfig.pauseDelayMs,
      profileDefaults.pauseDelayMs,
      fallback.pauseDelayMs
    );

    result.resumeDelayMs = ConfigMerger.pick(
      userConfig.resumeDelayMs,
      profileDefaults.resumeDelayMs,
      fallback.resumeDelayMs
    );

    result.kalman = ConfigMerger.pick(
      userConfig.kalman,
      profileDefaults.kalman,
      fallback.kalman
    );

    result.kalmanOptions = ConfigMerger.pickOptions(
      userConfig.kalmanOptions,
      profileDefaults.kalmanOptions,
      fallback.kalmanOptions
    );

    result.source = userConfig.source;
    result.unit = userConfig.unit;

    ConfigMerger.normalize(result);
    return result;
  }

  private static normalize(config: TrackingConfig): void {
    config.minAccuracyMeters = ConfigMerger.clamp(config.minAccuracyMeters, 0.1, 1000);
    config.strideLengthMeters = ConfigMerger.clamp(config.strideLengthMeters, 0.2, 1.5);
    config.poolLengthMeters = ConfigMerger.clamp(config.poolLengthMeters, 10, 100);
    config.updateInveralsMs = ConfigMerger.clamp(config.updateInveralsMs, 200, 10000);
    config.pauseSpeedMps = Math.max(0, config.pauseSpeedMps);
    config.resumeSpeedMps = Math.max(0, config.resumeSpeedMps);
    config.pauseDelayMs = Math.max(0, config.pauseDelayMs);
    config.resumeDelayMs = Math.max(0, config.resumeDelayMs);
  }

  private static clamp(value: number, min: number, max: number): number {
    return Math.min(max, Math.max(min, value));
  }

  private static pick(user: number, profile: number, fallback: number): number {
    if (user >= 0) {
      return user;
    }
    if (profile >= 0) {
      return profile;
    }
    return fallback;
  }

  private static pickOptions(user?: SpeedFilterOptions, profile?: SpeedFilterOptions,
    fallback?: SpeedFilterOptions): SpeedFilterOptions | undefined {
    if (user !== undefined) {
      return user;
    }
    if (profile !== undefined) {
      return profile;
    }
    return fallback;
  }
}
