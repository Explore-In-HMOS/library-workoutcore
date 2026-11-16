export interface TrackingListener {
  onUpdate(update: TrackingUpdate): void;
}

export interface TrackingUpdate {
  timer: TimerMetrics;
  movement: MovementMetrics;
  gps: GpsMetrics;
  steps: StepMetrics;
  heartRate: HeartRateMetrics;
  swim: SwimMetrics;
}

export interface StepMetrics {
  stepCount: number;
  cadenceSpm: number;
}

export interface GpsMetrics {
  latitude: number;
  longitude: number;
  altitude: number;
  accuracy: number;
  direction: number;
}

export interface HeartRateMetrics {
  bpm: number;
  avgBpm: number;
  maxBpm: number;
  minBpm: number;
}

export interface SwimMetrics {
  strokeCount: number;
  strokeRateSpm: number;
  style: number;
  lapCount: number;
}

export interface MovementMetrics {
  distanceMeters: number;
  speed: number;
  avgSpeed: number;
  maxSpeed: number;
}

export interface TimerMetrics {
  startTime: number;
  endTime: number;
  activeSeconds: number;
  elapsedSeconds: number;
  durationSeconds: number;
  pausedSeconds: number;
  paused: boolean;
}

export interface TrackPoint {
  latitude: number;
  longitude: number;
  accuracy: number;
  speed: number;
  timestamp: number;
  altitude: number;
  direction: number;
}

export enum TrackErrorCode {
  PERMISSION_DENIED = 1,
  LOCATION_UNAVAILABLE = 2,
  SENSOR_UNAVAILABLE = 3,
  INVALID_STATE = 4,
  HEART_RATE_UNAVAILABLE = 5,
  INTERNAL = 99
}

export interface TrackError {
  code: TrackErrorCode;
  message: string;
}