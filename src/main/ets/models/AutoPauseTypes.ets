export enum PauseState {
  ACTIVE = 'active',
  AUTO_PAUSED = 'auto_paused',
  MANUAL_PAUSED = 'manual_paused'
}

export interface AutoPauseOptions {
  pauseSpeedMps: number;
  resumeSpeedMps: number;
  pauseDelayMs: number;
  resumeDelayMs: number;
  minGpsAccuracyM: number;
  maxPointAgeMs: number;
}

export function defaultAutoPauseOptions(): AutoPauseOptions {
  const o: AutoPauseOptions = {
    pauseSpeedMps: 0.5,
    resumeSpeedMps: 0.8,
    pauseDelayMs: 5000,
    resumeDelayMs: 2000,
    minGpsAccuracyM: 50,
    maxPointAgeMs: 10000
  };
  return o;
}
