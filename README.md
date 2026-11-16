> **Note:** To access all shared projects, get information about environment setup, and view other guides, please visit [Explore-In-HMOS Index](https://github.com/Explore-In-HMOS/hmos-index).

# WorkoutCore

A sport tracking library for HarmonyOS wearables, written in ArkTS. Give it a sport type, start it, and it reports distance, speed, duration, steps, heading, heart rate, swim strokes, swim style and lap count on a fixed interval, so a workoutcore screen only has to draw numbers.

The library has no UI and requests no permissions. It measures and reports; the app owns the screen, the permission prompts and the saved session.

## How to Install

```
ohpm install @explore-in-hmos/workoutcore
```

## Usage

Build a config for the sport, hand it to a client, listen, start:

```ts
import {
  TrackingClient,
  TrackingConfig,
  TrackingConfigBuilder,
  SportType,
  TrackingUpdate,
  TrackError
} from '@explore-in-hmos/workoutcore';

const RUN_CONFIG: TrackingConfig = new TrackingConfigBuilder(SportType.RUNNING).build();

@Entry
@ComponentV2
struct RunPage {
  @Local distance: number = 0;
  @Local seconds: number = 0;
  private client: TrackingClient = new TrackingClient();

  aboutToAppear(): void {
    this.client.onError((e: TrackError) => {
      console.error(`workoutcore ${e.code}: ${e.message}`);
    });
    this.client.onUpdate((u: TrackingUpdate) => {
      this.distance = u.movement.distanceMeters;
      this.seconds = u.timer.activeSeconds;
    });
    this.client.init(RUN_CONFIG);
  }

  aboutToDisappear(): void {
    this.client.stop();
  }

  build() {
    Column({ space: 8 }) {
      Text(`${(this.distance / 1000).toFixed(2)} km`)
      Text(`${this.seconds} s`)
      Button('Start').onClick(() => this.client.start())
      Button('Stop').onClick(() => this.client.stop())
    }
  }
}
```

Copy the fields you show into your own state. `onUpdate` passes the same `TrackingUpdate` object every time, so assigning the object itself to a `@Local` does not trigger a re-render.

The sport type is the first constructor argument and defaults to `RUNNING` if omitted. Everything else is optional; the sport profile fills in what you leave out.

### Swimming

```ts
const SWIM_CONFIG: TrackingConfig = new TrackingConfigBuilder(SportType.SWIMMING)
  .poolLength(25)
  .build();
```

`poolLength` defaults to 25 metres. `swimStyle` arrives as a number:

```ts
const STYLE_NAMES: string[] = ['Freestyle', 'Breaststroke', 'Backstroke', 'Butterfly', 'Transition'];

function styleName(style: number): string {
  return style < 0 ? '—' : STYLE_NAMES[style];
}
```

### Treadmill

Distance comes from steps, so set the user's stride length if you know it:

```ts
const TREADMILL_CONFIG: TrackingConfig = new TrackingConfigBuilder(SportType.INDOOR_RUN)
  .strideLength(0.82)
  .build();
```

### Cycling, with overrides

Only give the settings you want to change:

```ts
const RIDE_CONFIG: TrackingConfig = new TrackingConfigBuilder(SportType.CYCLING)
  .minAccuracy(20)
  .updateInterval(2000)
  .build();
```

Keep configs at module level, as above, rather than building one inside `build()`. `build()` returns a copy: changing the builder afterwards does not change a config that was already built.

### Pause and resume

`pause()` and `resume()` work manually. When `autoPause(true)` is set and location is on, `GpsAutoPause` pauses after the configured slow-speed delay and resumes after the configured fast-speed delay. A manual pause is never cleared by the automatic logic.

## API

### Classes

| Class / type | Purpose |
|---|---|
| `TrackingClient` | Starts and stops the sensors, runs the calculations, reports updates and errors |
| `TrackingConfigBuilder` | Collects settings; `build()` returns a copy |
| `TrackingConfig` | Settings, passed to `init()` |
| `TrackingUpdate` | The values reported on every update |
| `TrackError` | `code` and `message` of a reported error |
| `SportType` | `RUNNING`, `WALKING`, `INDOOR_RUN`, `CYCLING`, `SWIMMING`, `WATER_SPORTS` |
| `TrackErrorCode` | Error codes, see below |
| `TrackPoint` | One GPS fix: latitude, longitude, altitude, accuracy, speed, direction, timestamp |
| `ClimbTracker` | Barometer-based elevation gain and loss |
| `RouteRecorder` | GPS route segments, Douglas-Peucker simplification and polyline encoding |
| `Logger` | Thin hilog wrapper; `Logger.setLevel()` silences levels |

### TrackingClient

| Method | Purpose |
|---|---|
| `init(config)` | Applies the config. Throws if called while running |
| `start()` | Starts the sensors and the update timer. Values start from zero |
| `stop()` | Stops all sensors and the timer, then sends one last update |
| `pause()` / `resume()` | Manual pause and resume; ignored while stopped |
| `isRunning()` | `true` between `start()` and `stop()` |
| `isPaused()` | `true` while paused |
| `snapshot()` | The latest values, without waiting for the next update |
| `onUpdate(cb)` | Sets the update listener. A second call replaces the first |
| `onError(cb)` | Sets the error listener. A second call replaces the first |
| `routeSegments()` | Recorded route, split at pause/resume boundaries |
| `routePolylines(toleranceM)` | Route segments as encoded polylines; `toleranceM > 0` simplifies first |

### Lifecycle

```
new TrackingClient()  →  init(config)  →  start()  →  pause()/resume()  →  stop()
                            ↑                                                 │
                            └─────────────────────────────────────────────────┘
```

| Case | Result |
|---|---|
| `start()` without `init()` | `onError` with `INVALID_STATE`; tracking does not start |
| `start()` while running | Ignored |
| `init()` while running | Throws; call `stop()` first |
| `pause()` / `resume()` while stopped | Ignored |
| `stop()` while stopped | Ignored |
| `start()` after `stop()` | New session, values from zero |

### Sport profiles

Each sport comes with its own profile. Settings resolve in three layers: **what you set > sport profile > library default**.

| | `RUNNING` | `WALKING` | `INDOOR_RUN` | `CYCLING` | `SWIMMING` | `WATER_SPORTS` |
|---|---|---|---|---|---|---|
| Distance from | GPS | GPS | Steps × stride | GPS | Laps × pool length | GPS |
| Location | on | on | off | on | off | on |
| Steps | off | off | on | off | off | off |
| Motion (accel + gyro) | off | off | off | off | on | off |
| Auto pause | on | on | off | on | off | off |
| Kalman speed filter | on | on | off | on | off | off |
| `pauseSpeedMps` | 0.5 | 0.5 | — | 1.0 | — | — |
| `resumeSpeedMps` | 0.8 | 0.8 | — | 1.5 | — | — |
| `strideLengthMeters` | — | — | 0.75 | — | — | — |
| `poolLengthMeters` | — | — | — | — | 25 | — |
| `updateIntervalMs` | 1000 | 1000 | 1000 | 1000 | 1000 | 1000 |

A dash means the sport does not use the setting. `minAccuracyMeters` defaults to 25 m for every sport.

### TrackingConfigBuilder

| Method | Default | Allowed | Purpose |
|---|---|---|---|
| `constructor(sport?)` | `RUNNING` | `SportType` | Picks the sport profile |
| `sport(value)` | `RUNNING` | `SportType` | Changes the sport before `build()` |
| `useLocation(on)` | per sport | `boolean` | GPS on or off |
| `useStep(on)` / `useSteps(on)` | per sport | `boolean` | Pedometer on or off |
| `useMotion(on)` | per sport | `boolean` | Accelerometer and gyroscope on or off |
| `minAccuracy(m)` | 25 | 0.1 to 1000 | GPS fixes with worse accuracy are dropped |
| `strideLength(m)` | 0.75 | 0.2 to 1.5 | Metres per step on the treadmill |
| `poolLength(m)` | 25 | 10 to 100 | Pool length for swimming |
| `updateInterval(ms)` / `intervals(ms)` | 1000 | 200 to 10000 | How often updates are emitted and GPS is requested |
| `autoPause(on)` | per sport | `boolean` | Automatic pause on slow speed |
| `pauseSpeed(mps)` | per sport | ≥ 0 | Speed below which the user counts as stopped |
| `resumeSpeed(mps)` | per sport | ≥ 0 | Speed above which auto-pause resumes |
| `pauseDelay(ms)` | 5000 | ≥ 0 | Slow speed must last this long before pausing |
| `resumeDelay(ms)` | 2000 | ≥ 0 | Fast speed must last this long before resuming |
| `kalman(on)` | per sport | `boolean` | Kalman speed filter on or off |
| `kalmanOptions(options)` | per sport | `SpeedFilterOptions` | Tuning for the speed filter |
| `source(source)` | — | `DistanceSource` | Stored on the config; not applied yet |
| `unit(unit)` | — | `DistanceUnit` | Stored on the config; not applied yet |
| `build()` | | | Returns a copy of the config |

A setter that receives an out-of-range value throws right away. `build()` also throws when location, steps and motion were all explicitly switched off.

### TrackingUpdate

`TrackingUpdate` is nested by category:

| Field | Unit | Filled for | Purpose |
|---|---|---|---|
| `timer.elapsedSeconds` | s | all | Time since `start()`, including pauses |
| `timer.activeSeconds` | s | all | Moving time, pauses excluded |
| `timer.pausedSeconds` | s | all | Time spent paused |
| `timer.durationSeconds` | s | all | Currently the same value as `activeSeconds` |
| `timer.paused` | | all | `true` while paused |
| `timer.startTime` / `timer.endTime` | ms | all | Session boundaries; `endTime` is 0 until stopped |
| `movement.distanceMeters` | m | all | Total distance this session |
| `movement.speed` | m/s | GPS, treadmill | Current speed; 0 while standing still or paused |
| `movement.avgSpeed` | m/s | GPS, treadmill | `distanceMeters / activeSeconds` |
| `movement.maxSpeed` | m/s | GPS, treadmill | Highest non-paused speed this session |
| `gps.latitude`, `gps.longitude` | ° | GPS | Latest fix |
| `gps.altitude` | m | GPS | Latest altitude |
| `gps.accuracy` | m | GPS | Latest horizontal accuracy |
| `gps.direction` | ° | GPS | Heading from the fix, 0 = north |
| `steps.stepCount` | steps | pedometer | Steps reported by the pedometer |
| `steps.cadenceSpm` | steps/min | — | Reserved; not calculated yet |
| `heartRate.bpm` | bpm | heart rate sensor | Latest value, -1 before the first reading |
| `heartRate.avgBpm`, `maxBpm`, `minBpm` | bpm | heart rate sensor | Session aggregates |
| `swim.strokeCount` | strokes | swimming | One full arm cycle is one stroke |
| `swim.strokeRateSpm` | strokes/min | — | Reserved; not calculated yet |
| `swim.style` | | swimming | -1 none yet, 0 freestyle, 1 breaststroke, 2 backstroke, 3 butterfly, 4 transition |
| `swim.lapCount` | laps | swimming | Pool lengths detected by the transition detector |

### TrackErrorCode

| Code | Value | Meaning |
|---|---|---|
| `PERMISSION_DENIED` | 1 | A required permission was not granted |
| `LOCATION_UNAVAILABLE` | 2 | Location service is off or there is no signal |
| `SENSOR_UNAVAILABLE` | 3 | The device lacks a required sensor |
| `INVALID_STATE` | 4 | Methods were called in the wrong order |
| `HEART_RATE_UNAVAILABLE` | 5 | Heart rate could not be read |
| `INTERNAL` | 99 | Unexpected failure |

### ClimbTracker

```ts
const climb = new ClimbTracker();
const ok = climb.start((data: ClimbData) => {
  this.gain = data.totalGainM;
  this.loss = data.totalLossM;
});
// ...
climb.stop();
```

`start()` returns `false` when the barometer is unavailable. `saveRecording(context)` writes a CSV under the app's `filesDir`.

## How It Works

**GPS distance.** Each fix is checked against `minAccuracyMeters` and the sign of its speed. Fixes below 0.28 m/s are treated as standing still and do not add distance. The first usable fix becomes the reference; later fixes add haversine distance and move the reference. Pausing freezes accumulation.

**Treadmill distance.** The pedometer counts steps since boot, so the first reading of a session becomes zero. Distance is steps × `strideLengthMeters`, and steps taken while paused are excluded.

**Speed filtering.** GPS sports feed the speed filter. With Kalman enabled it is a two-state `[v, a]` filter whose measurement noise scales with GPS accuracy and whose acceleration and speed are physically clamped. With Kalman disabled the pass-through strategy only drops invalid speeds and clamps to `maxSpeedMps`.

**Auto pause.** The filtered speed feeds `GpsAutoPause`. Speed below `pauseSpeedMps` for `pauseDelayMs` pauses the session; speed above `resumeSpeedMps` for `resumeDelayMs` resumes it. Poor accuracy and unknown speeds are ignored, and long GPS gaps reset the dwell counters.

**Strokes.** Each accelerometer axis is smoothed (1 Hz low-pass), the slow gravity component is subtracted (0.1 Hz baseline), and the axis with the most movement is picked automatically, so it works however the watch sits on the wrist. A stroke is counted when the signal crosses +3.0 and then −3.0, with at least 700 ms between strokes.

**Swim style.** A small 1D convolutional network (int8 weights, plain ArkTS, no native code) reads 3 seconds of accelerometer and gyroscope data, every 1.5 seconds. Sensor data is resampled to 30 Hz internally. The reported style is the majority of the last five decisions.

**Laps.** A transition detector runs on the same motion stream. `LapCounter` closes a lap on a transition and on long blocks, with lap duration bounds scaled by pool length. `lapCount` and, for swimming, `distanceMeters` come from it.

**Route.** When location is on, `RouteRecorder` stores points at least 10 m apart, also keeping turns of 25° or more. Pause/resume starts a new segment; `routePolylines()` optionally simplifies each segment before encoding.

## Technology

### Stack

- ArkTS
- DevEco Studio
- No native code, no MindSpore, no network

### Required Permissions

The library does not request permissions. The app must hold these before calling `start()`, depending on the features it uses:

| Permission | Needed for |
|---|---|
| `ohos.permission.LOCATION` and `ohos.permission.APPROXIMATELY_LOCATION` | Running, walking, cycling, water sports, route recording |
| `ohos.permission.ACTIVITY_MOTION` | Pedometer (walking, treadmill) |
| `ohos.permission.ACCELEROMETER` and `ohos.permission.GYROSCOPE` | Swimming, climb motion detection |
| `ohos.permission.READ_HEALTH_DATA` | Heart rate |

Tracking with the screen off needs a background task started by the app.

## Directory Structure

```
Index.ets                                   public API
src/main/ets/
  api/TrackingClient.ets                    facade: lifecycle, sensors, updates
  api/TrackingConfig.ets                    settings container
  api/TrackingConfigBuilder.ets             settings validation
  api/ConfigMerger.ets                      user > profile > default resolution
  api/DefaultSettings.ets                   library defaults
  api/ClimbTracker.ets                      barometer elevation tracker
  models/TrackingTypes.ets                  sport, source and unit enums
  models/TrackingListener.ets               update, point and error types
  models/AutoPauseTypes.ets                 auto-pause state and options
  models/SpeedFilterTypes.ets               speed filter options and result
  models/ClimbTypes.ets                     climb data and options
  domain/GeoMath.ets                        haversine distance
  domain/track/ITrackCalculator.ets         distance strategy contract
  domain/track/GpsTrackCalculator.ets       GPS distance with filters
  domain/track/StepTrackCalculator.ets      step-based distance
  domain/filter/*.ets                       Kalman, pass-through and low-pass filters
  domain/autopause/GpsAutoPause.ets         speed-based auto pause
  domain/route/RouteRecorder.ets            route segments, simplification, polyline
  domain/climb/ClimbCalculator.ets          pressure-based elevation
  domain/sport/SportProfile.ets             sport profile contract
  domain/sport/SportProfileFactory.ets      sport type to profile
  domain/sport/*Profile.ets                 per-sport defaults
  domain/swim/StrokeDetector.ets            stroke counter
  domain/swim/LapCounter.ets                lap and pool distance
  domain/swim/SwimStyleCnn.ets              swim style classifier
  domain/swim/SwimTransitionDetector.ets    lap transition detector
  domain/swim/weight/SwimCnnWeights.ets     int8 model weights
  domain/swim/test/*.ets                    golden tests for the swim models
  source/GpsSource.ets                      location provider
  source/StepSource.ets                     pedometer provider
  source/AccelerometerSource.ets            accelerometer provider
  source/GyroscopeSource.ets                gyroscope provider
  source/HRSource.ets                       heart rate provider
  util/Logger.ets                           hilog wrapper
```

## Constraints and Restrictions

- **Errors are partly reported.** Only `INVALID_STATE` is emitted by the client today. A denied permission, location off or a missing sensor is not raised as an error.
- **`source()` and `unit()` are stored but not applied.** The sport profile still decides how distance is calculated.
- **`steps.cadenceSpm` and `swim.strokeRateSpm` are reserved** and stay 0.
- **Duration is counted by the update timer.** If the system delays the timer in the background, duration can come out short.
- **Sensors are assumed to run at 50 Hz** for stroke counting.
- **The swim style model was trained on wrist data from another device.** Axis directions and the wrist the watch is worn on can affect accuracy.
- **Only pool swimming** is supported; open water is not.
- **Field tests are pending.** Track running and pool swimming have not been verified on site yet.

## Supported Devices

- Watch 5
- Watch Ultimate 2

## License

**WorkoutCore** is distributed under the terms of the MIT License. See the [LICENSE](LICENSE) for more information.
