import { TrackingUpdate, TrackPoint, TrackError, TrackErrorCode } from "../models/TrackingListener";
import { SportProfileFactory } from "../domain/sport/SportProfileFactory";
import { ConfigMerger } from "./ConfigMerger";
import { TrackingConfig } from "./TrackingConfig";
import { ITrackCalculator } from "../domain/track/ITrackCalculator";
import { GpsSource } from "../source/GpsSource";
import { SourceState } from "../models/TrackingTypes";
import { StepSource } from "../source/StepSource";
import { HRSource } from "../source/HRSource";
import { AccelerometerSource } from "../source/AccelerometerSource";
import { StrokeDetector } from "../domain/swim/StrokeDetector";
import { GyroscopeSource } from "../source/GyroscopeSource";
import { SwimStyleCnn } from "../domain/swim/SwimStyleCnn";
import { LapCounter } from "../domain/swim/LapCounter";
import { SwimTransitionDetector } from "../domain/swim/SwimTransitionDetector";
import { AutoPauseOptions, PauseState, defaultAutoPauseOptions } from "../models/AutoPauseTypes";
import { GpsAutoPause } from "../domain/autopause/GpsAutoPause";
import { RouteRecorder, RoutePoint } from "../domain/route/RouteRecorder";
import { Logger } from "../util/Logger";

export class TrackingClient {
  private updateCallback: ((update: TrackingUpdate) => void) | undefined = undefined;
  private errorCallback: ((error: TrackError) => void) | undefined = undefined;
  private config: TrackingConfig = new TrackingConfig();
  private running: boolean = false;
  private timerId: number = -1;
  private calculator: ITrackCalculator | undefined = undefined;
  private routeRecorder: RouteRecorder | undefined = undefined;
  private gpsSource: GpsSource = new GpsSource();
  private stepSource: StepSource = new StepSource();
  private hrSource: HRSource = new HRSource();
  private accelSource: AccelerometerSource = new AccelerometerSource();
  private strokeDetector: StrokeDetector | undefined = undefined;
  private gyroSource: GyroscopeSource = new GyroscopeSource();
  private styleCnn: SwimStyleCnn | undefined = undefined;
  private lastGx: number = 0;
  private lastGy: number = 0;
  private lastGz: number = 0;
  private transDetector: SwimTransitionDetector | undefined = undefined;
  private lapCounter: LapCounter | undefined = undefined;
  private autoPause: GpsAutoPause | undefined = undefined;
  private paused: boolean = false;
  private startMs: number = 0;
  private pausedAccumMs: number = 0;
  private pausedAtMs: number = -1;
  private totalHeartRate: number = 0;
  private heartRateCount: number = 0;
  private maxBpm: number = 0;
  private minBpm: number = 0;
  private maxSpeed: number = 0;
  private stepBase: number = -1;
  private initialized: boolean = false;
  private log: Logger = new Logger('TrackingClient');

  init(userConfig: TrackingConfig): void {
    if (this.running) {
      throw new Error('Cannot change configuration while tracking; call stop() first');
    }

    const profile = SportProfileFactory.create(userConfig.sport);
    this.config = ConfigMerger.merge(profile.defaults(), userConfig);
    this.calculator = profile.createCalculator(this.config);

    if (this.config.useLocation === SourceState.ON) {
      this.routeRecorder = new RouteRecorder(10, 25, 5000);
    } else {
      this.routeRecorder = undefined;
    }

    this.autoPause = undefined;
    if (this.config.autoPause === SourceState.ON &&
      this.config.useLocation === SourceState.ON) {
      const base: AutoPauseOptions = defaultAutoPauseOptions();
      const options: AutoPauseOptions = {
        pauseSpeedMps: this.config.pauseSpeedMps,
        resumeSpeedMps: this.config.resumeSpeedMps,
        pauseDelayMs: this.config.pauseDelayMs,
        resumeDelayMs: this.config.resumeDelayMs,
        minGpsAccuracyM: this.config.minAccuracyMeters,
        maxPointAgeMs: base.maxPointAgeMs
      };
      this.autoPause = new GpsAutoPause(options);
    }

    if (this.config.useMotion === SourceState.ON) {
      this.strokeDetector = new StrokeDetector(50, 3.0, 700);
      this.styleCnn = new SwimStyleCnn();
      this.transDetector = new SwimTransitionDetector();
      this.lapCounter = new LapCounter(this.config.poolLengthMeters);
    } else {
      this.strokeDetector = undefined;
      this.styleCnn = undefined;
      this.transDetector = undefined;
      this.lapCounter = undefined;
    }

    this.initialized = true;
  }

  onUpdate(listener: (update: TrackingUpdate) => void): void {
    this.updateCallback = listener;
  }

  onError(listener: (error: TrackError) => void): void {
    this.errorCallback = listener;
  }

  private current: TrackingUpdate = {
    timer: {
      startTime: 0,
      endTime: 0,
      durationSeconds: 0,
      elapsedSeconds: 0,
      pausedSeconds: 0,
      activeSeconds: 0,
      paused: false
    },
    movement: {
      distanceMeters: 0,
      speed: 0,
      avgSpeed: 0,
      maxSpeed: 0
    },
    gps: {
      latitude: 0,
      longitude: 0,
      altitude: 0,
      accuracy: 0,
      direction: 0
    },
    steps: {
      stepCount: 0,
      cadenceSpm: 0
    },
    heartRate: {
      bpm: -1,
      avgBpm: 0,
      maxBpm: 0,
      minBpm: 0
    },
    swim: {
      strokeCount: 0,
      strokeRateSpm: 0,
      style: 0,
      lapCount: 0
    }
  };

  start(): void {
    if (!this.initialized) {
      this.emitError(TrackErrorCode.INVALID_STATE, 'init() must be called before start()');
      return;
    }
    if (this.running) {
      return;
    }
    this.running = true;
    this.resetSession();

    if (this.config.useLocation === SourceState.ON) {
      this.gpsSource.start(this.config.updateInveralsMs, (p: TrackPoint) => {
        this.onLocation(p);
      });
    }

    if (this.config.useStep === SourceState.ON) {
      this.stepSource.start((count: number) => {
        this.onStep(count);
      });
    }

    if (this.config.useMotion === SourceState.ON) {
      this.gyroSource.start((x: number, y: number, z: number) => {
        this.lastGx = x;
        this.lastGy = y;
        this.lastGz = z;
      });

      this.accelSource.start((x: number, y: number, z: number, t: number) => {
        this.onMotion(x, y, z, t);
      });
    }

    this.hrSource.start((bpm: number) => {
      this.onHeartRate(bpm);
    });

    this.timerId = setInterval(() => {
      const activeSeconds: number = this.refreshTimer(Date.now());

      if (this.lapCounter !== undefined) {
        this.current.movement.distanceMeters = this.lapCounter.distanceMeters();
      } else if (this.calculator !== undefined) {
        this.current.movement.distanceMeters = this.calculator.totalMeters();
      }

      if (this.calculator !== undefined) {
        if (this.paused) {
          this.current.movement.speed = 0;
        } else {
          const speed: number = this.calculator.currentSpeedMps();
          this.current.movement.speed = speed;
          this.maxSpeed = Math.max(this.maxSpeed, speed);
          this.current.movement.maxSpeed = this.maxSpeed;
        }
        this.current.movement.avgSpeed = activeSeconds > 0
          ? this.current.movement.distanceMeters / activeSeconds
          : 0;
      }
      this.emitUpdate();
    }, this.config.updateInveralsMs);
  }

  pause(): void {
    if (!this.running) {
      return;
    }
    if (this.autoPause !== undefined) {
      this.autoPause.manualPause();
    }
    if (this.routeRecorder !== undefined) {
      this.routeRecorder.breakSegment();
    }
    this.applyPauseState(true, Date.now());
  }

  resume(): void {
    if (!this.running) {
      return;
    }
    if (this.autoPause !== undefined) {
      this.autoPause.manualResume();
    }
    if (this.routeRecorder !== undefined) {
      this.routeRecorder.breakSegment();
    }
    this.applyPauseState(false, Date.now());
  }

  isRunning(): boolean {
    return this.running;
  }

  isPaused(): boolean {
    return this.paused;
  }

  snapshot(): TrackingUpdate {
    return this.current;
  }

  private resetSession(): void {
    if (this.calculator !== undefined) {
      this.calculator.reset();
    }
    if (this.routeRecorder !== undefined) {
      this.routeRecorder.reset();
    }
    if (this.autoPause !== undefined) {
      this.autoPause.reset();
    }
    if (this.strokeDetector !== undefined) {
      this.strokeDetector.reset();
    }
    if (this.styleCnn !== undefined) {
      this.styleCnn.reset();
    }
    if (this.transDetector !== undefined) {
      this.transDetector.reset();
    }
    if (this.lapCounter !== undefined) {
      this.lapCounter.reset();
    }

    this.paused = false;
    this.pausedAccumMs = 0;
    this.pausedAtMs = -1;
    this.maxSpeed = 0;
    this.maxBpm = 0;
    this.minBpm = 0;
    this.totalHeartRate = 0;
    this.heartRateCount = 0;
    this.stepBase = -1;
    this.startMs = Date.now();

    this.current.timer.startTime = this.startMs;
    this.current.timer.endTime = 0;
    this.current.timer.durationSeconds = 0;
    this.current.timer.elapsedSeconds = 0;
    this.current.timer.pausedSeconds = 0;
    this.current.timer.activeSeconds = 0;
    this.current.timer.paused = false;
    this.current.movement.distanceMeters = 0;
    this.current.movement.speed = 0;
    this.current.movement.avgSpeed = 0;
    this.current.movement.maxSpeed = 0;
    this.current.steps.stepCount = 0;
    this.current.steps.cadenceSpm = 0;
    this.current.heartRate.bpm = -1;
    this.current.heartRate.avgBpm = 0;
    this.current.heartRate.maxBpm = 0;
    this.current.heartRate.minBpm = 0;
    this.current.swim.strokeCount = 0;
    this.current.swim.strokeRateSpm = 0;
    this.current.swim.style = 0;
    this.current.swim.lapCount = 0;
  }

  private pausedMs(now: number): number {
    return this.pausedAccumMs + (this.pausedAtMs >= 0 ? now - this.pausedAtMs : 0);
  }

  private refreshTimer(now: number): number {
    const elapsedMs: number = Math.max(0, now - this.startMs);
    const pausedMs: number = Math.min(elapsedMs, this.pausedMs(now));
    const activeSeconds: number = Math.floor((elapsedMs - pausedMs) / 1000);
    this.current.timer.elapsedSeconds = Math.floor(elapsedMs / 1000);
    this.current.timer.pausedSeconds = Math.floor(pausedMs / 1000);
    this.current.timer.activeSeconds = activeSeconds;
    this.current.timer.durationSeconds = activeSeconds;
    return activeSeconds;
  }

  private applyPauseState(paused: boolean, now: number): void {
    if (paused === this.paused) {
      return;
    }
    if (paused) {
      this.pausedAtMs = now;
      if (this.calculator !== undefined) {
        this.calculator.pause();
      }
    } else {
      if (this.pausedAtMs >= 0) {
        this.pausedAccumMs += now - this.pausedAtMs;
      }
      this.pausedAtMs = -1;
      if (this.calculator !== undefined) {
        this.calculator.resume();
      }
    }
    this.paused = paused;
    this.current.timer.paused = paused;
  }

  private onStep(count: number): void {
    if (this.calculator !== undefined) {
      this.calculator.onStep(count);
    }
    if (this.stepBase < 0) {
      this.stepBase = count;
    }
    this.current.steps.stepCount = Math.max(0, count - this.stepBase);
  }

  private emitUpdate(): void {
    if (this.updateCallback !== undefined) {
      this.updateCallback(this.current);
    }
  }

  private emitError(code: TrackErrorCode, message: string): void {
    if (this.errorCallback !== undefined) {
      this.errorCallback({ code: code, message: message });
    }
  }

  private onLocation(p: TrackPoint): void {
    const now: number = Date.now();

    if (this.calculator !== undefined) {
      this.calculator.onLocation(p);

      if (this.routeRecorder !== undefined && p.accuracy <= this.config.minAccuracyMeters) {
        this.routeRecorder.onPoint(p.latitude, p.longitude, p.timestamp, p.altitude);
      }
      this.log.d(`speed raw=${p.speed.toFixed(2)} filtered=${this.calculator.currentSpeedMps().toFixed(2)} m/s`);
    }

    this.current.gps.latitude = p.latitude;
    this.current.gps.longitude = p.longitude;
    this.current.gps.altitude = p.altitude;
    this.current.gps.accuracy = p.accuracy;
    this.current.gps.direction = p.direction;

    if (this.autoPause !== undefined) {
      const speedMps: number = this.calculator !== undefined
        ? this.calculator.currentSpeedMps() : p.speed;
      const next: PauseState = this.autoPause.onSpeed(speedMps, p.accuracy, now);
      this.applyPauseState(next !== PauseState.ACTIVE, now);
    }
  }

  private onMotion(x: number, y: number, z: number, t: number): void {
    if (this.strokeDetector !== undefined) {
      this.strokeDetector.onSample(x, y, z, t);
      this.current.swim.strokeCount = this.strokeDetector.strokeCount();
    }
    if (this.styleCnn !== undefined) {
      this.styleCnn.onSample(x, y, z, this.lastGx, this.lastGy, this.lastGz, t);
      this.current.swim.style = this.styleCnn.currentStyle();
    }

    if (this.transDetector !== undefined && this.lapCounter !== undefined) {
      const probability: number = this.transDetector.onSample(
        x, y, z, this.lastGx, this.lastGy, this.lastGz, t);
      if (probability >= 0) {
        this.lapCounter.onProbability(probability, this.transDetector.timeOfLastMs());
        this.current.swim.lapCount = this.lapCounter.lapCount();
        this.current.movement.distanceMeters = this.lapCounter.distanceMeters();
      }
    }
  }

  private onHeartRate(bpm: number): void {
    if (bpm <= 0 || bpm === 255) {
      return;
    }
    this.current.heartRate.bpm = bpm;
    this.maxBpm = Math.max(this.maxBpm, bpm);
    if (this.minBpm === 0 || bpm < this.minBpm) {
      this.minBpm = bpm;
    }
    this.current.heartRate.maxBpm = this.maxBpm;
    this.current.heartRate.minBpm = this.minBpm;
    this.heartRateCount += 1;
    this.totalHeartRate += bpm;
    this.current.heartRate.avgBpm = this.totalHeartRate / this.heartRateCount;
  }

  stop(): void {
    if (!this.running) {
      return;
    }
    this.running = false;
    this.gpsSource.stop();
    this.stepSource.stop();
    this.accelSource.stop();
    this.gyroSource.stop();
    this.hrSource.stop();
    clearInterval(this.timerId);
    this.timerId = -1;
    if (this.routeRecorder !== undefined) {
      this.routeRecorder.finish();
    }
    const activeSeconds: number = this.refreshTimer(Date.now());
    this.current.timer.endTime = Date.now();
    this.current.movement.speed = 0;
    this.current.movement.avgSpeed = activeSeconds > 0
      ? this.current.movement.distanceMeters / activeSeconds
      : 0;
    this.emitUpdate();
    this.paused = false;
    this.pausedAtMs = -1;
    this.current.timer.paused = false;
  }

  routeSegments(): RoutePoint[][] {
    return this.routeRecorder !== undefined ? this.routeRecorder.route() : [];
  }

  routePolylines(toleranceM: number): string[] {
    if (this.routeRecorder === undefined) {
      return [];
    }
    const segments: RoutePoint[][] = toleranceM > 0
      ? this.routeRecorder.simplified(toleranceM)
      : this.routeRecorder.route();

    const out: string[] = [];
    for (const segment of segments) {
      out.push(RouteRecorder.encodePolyline(segment));
    }
    return out;
  }
}
