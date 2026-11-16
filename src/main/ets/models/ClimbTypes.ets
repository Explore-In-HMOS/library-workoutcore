export interface ClimbData {
  totalGainM: number;
  totalLossM: number;
  relativeAltitudeM: number;
  rawAltitudeM: number;
  pressureHpa: number;
  moving: boolean;
  motionSd: number;
  ready: boolean;
}

export interface ClimbOptions {
  turnThresholdM: number;
  smoothingAlpha: number;
  motionThreshold: number;
  emitIntervalMs: number;
}

export function defaultClimbOptions(): ClimbOptions {
  const o: ClimbOptions = {
    turnThresholdM: 2.0,
    smoothingAlpha: 0.05,
    motionThreshold: 0.25,
    emitIntervalMs: 1000
  };
  return o;
}