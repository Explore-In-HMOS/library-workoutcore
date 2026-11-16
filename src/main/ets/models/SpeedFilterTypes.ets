/**
 * Speed filter settings. The Kalman and pass-through strategies share this set;
 * per-sport differences are overridden in SportProfile.defaults().
 */
export interface SpeedFilterOptions {
  velocityProcessNoise: number;
  accelProcessNoise: number;
  measurementNoiseBase: number;
  referenceAccuracyMeters: number;
  maxAccelMps2: number;
  maxSpeedMps: number;
  zeroSpeedThresholdMps: number;
  accelDamping: number;
}

export interface FilteredSpeedResult {
  speedMps: number;
  rawSpeedMps: number;
  estimatedAccelMps2: number;
  isKalmanActive: boolean;
  isSpikeClamped: boolean;
}

/**
 * Running defaults. maxSpeedMps rejects anything above 12.5 m/s (45 km/h) as
 * physically impossible; sports such as cycling override it in their profile.
 */
export function defaultSpeedFilterOptions(): SpeedFilterOptions {
  const o: SpeedFilterOptions = {
    velocityProcessNoise: 0.35,
    accelProcessNoise: 0.25,
    measurementNoiseBase: 1.80,
    referenceAccuracyMeters: 5.0,
    maxAccelMps2: 5.5,
    maxSpeedMps: 12.5,
    zeroSpeedThresholdMps: 0.35,
    accelDamping: 0.88
  };
  return o;
}
