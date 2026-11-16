import {
  TrackingClient,
  TrackingConfigBuilder,
  SportType,
  TrackingUpdate,
  TrackError
} from '@explore-in-hmos/workoutcore';
import PermissionsUtil from '../util/PermissionUtil';

@Entry
@ComponentV2
struct Index {
  private client: TrackingClient = new TrackingClient();
  @Local distance: number = 0;
  @Local elapsed: number = 0;
  @Local active: number = 0;
  @Local paused: boolean = false;
  @Local running: boolean = false;
  @Local speed: number = 0;
  @Local step: number = 0;
  @Local error: string = '';
  @Local heartRate: number = 0;
  @Local heading: number = 0;
  @Local altitude: number = 0;
  @Local avgSpeed: number = 0;
  @Local maxSpeed: number = 0;
  @Local avgHeartRate: number = 0;

  aboutToAppear(): void {
    PermissionsUtil.requestPermissions([
      'ohos.permission.ACCELEROMETER',
      'ohos.permission.ACTIVITY_MOTION',
      'ohos.permission.GYROSCOPE',
      'ohos.permission.READ_HEALTH_DATA',
      'ohos.permission.LOCATION',
      'ohos.permission.APPROXIMATELY_LOCATION',
      'ohos.permission.INTERNET'
    ]);

    // To change Kalman tuning: .kalmanOptions({ ...defaultSpeedFilterOptions(), maxSpeedMps: 20 })
    const config = new TrackingConfigBuilder(SportType.RUNNING)
      .minAccuracy(50)
      .kalman(true)
      .build();

    this.client.init(config);

    this.client.onUpdate((update: TrackingUpdate) => {
      this.distance = update.movement.distanceMeters;
      this.elapsed = update.timer.elapsedSeconds;
      this.active = update.timer.activeSeconds;
      this.paused = update.timer.paused;
      this.speed = update.movement.speed;
      this.step = update.steps.stepCount;
      this.heartRate = update.heartRate.bpm;
      this.heading = update.gps.direction;
      this.altitude = update.gps.altitude;
      this.avgSpeed = update.movement.avgSpeed;
      this.maxSpeed = update.movement.maxSpeed;
      this.avgHeartRate = update.heartRate.avgBpm;
    });

    this.client.onError((error: TrackError) => {
      this.error = `[${error.code}] ${error.message}`;
    });
  }

  private formatDuration(seconds: number): string {
    const s: number = Math.floor(seconds % 60);
    const m: number = Math.floor(seconds / 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  aboutToDisappear(): void {
    this.client.stop();
  }

  build() {
    Scroll() {
      Column({ space: 18 }) {
        Text(`${(this.distance / 1000).toFixed(2)} km`)
          .fontSize(20)

        Text(this.paused ? 'PAUSED' : 'RECORDING')
          .fontSize(16)
          .fontColor(this.paused ? Color.Orange : Color.Green)

        Text(`elapsed ${this.formatDuration(this.elapsed)}  /  active ${this.formatDuration(this.active)}`)
          .fontSize(20)

        Text(`${this.step} steps`)
          .fontSize(20)

        Text(`${(this.speed * 3.6).toFixed(1)} km/h`)
          .fontSize(20)

        Text(`${this.heartRate} bpm`)
          .fontSize(20)

        Button('Start')
          .width(160)
          .height(50)
          .enabled(!this.running)
          .onClick(() => {
            this.client.start();
            this.running = true;
          })

        Button(this.paused ? 'Resume' : 'Pause')
          .width(160)
          .height(50)
          .enabled(this.running)
          .onClick(() => {
            if (this.paused) {
              this.client.resume();
            } else {
              this.client.pause();
            }
          })

        Button('Stop')
          .width(160)
          .height(50)
          .enabled(this.running)
          .onClick(() => {
            this.client.stop();
            this.running = false;
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .scrollBar(BarState.Off)
    .align(Alignment.Center)
  }
}
