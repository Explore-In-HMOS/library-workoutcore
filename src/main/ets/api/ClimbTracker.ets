import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ClimbData, ClimbOptions, defaultClimbOptions } from '../models/ClimbTypes';
import { ClimbCalculator } from '../domain/climb/ClimbCalculator';
import { Logger } from '../util/Logger';

export type ClimbListener = (data: ClimbData) => void;

const BARO_INTERVAL_MS: number = 200;
const ACCEL_INTERVAL_MS: number = 20;

export class ClimbTracker {
  private opt: ClimbOptions;
  private calc: ClimbCalculator;
  private listener: ClimbListener | undefined = undefined;
  private timerId: number = -1;
  private running: boolean = false;
  private log: Logger = new Logger('ClimbTracker');

  private baroHandler: ((data: sensor.BarometerResponse) => void) | undefined = undefined;
  private accelHandler: ((data: sensor.AccelerometerResponse) => void) | undefined = undefined;

  constructor(options?: ClimbOptions) {
    this.opt = options !== undefined ? options : defaultClimbOptions();
    this.calc = new ClimbCalculator(this.opt);
  }

  static hasBarometer(): boolean {
    try {
      const s = sensor.getSingleSensorSync(sensor.SensorId.BAROMETER);
      return s !== undefined && s !== null;
    } catch (err) {
      return false;
    }
  }

  start(listener: ClimbListener): boolean {
    if (this.running) {
      return true;
    }
    this.listener = listener;
    this.calc.reset();

    this.baroHandler = (data: sensor.BarometerResponse) => {
      this.calc.onPressure(data.pressure);
    };
    this.accelHandler = (data: sensor.AccelerometerResponse) => {
      this.calc.onAccel(data.x, data.y, data.z);
    };

    try {
      sensor.on(sensor.SensorId.BAROMETER, this.baroHandler,
        { interval: BARO_INTERVAL_MS * 1000000 });
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`barometer unavailable ${e.code}: ${e.message}`);
      this.baroHandler = undefined;
      this.accelHandler = undefined;
      this.listener = undefined;
      return false;
    }

    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, this.accelHandler,
        { interval: ACCEL_INTERVAL_MS * 1000000 });
    } catch (err) {
      const e = err as BusinessError;
      this.log.w(`accelerometer unavailable ${e.code}: ${e.message}; rest detection disabled`);
      this.accelHandler = undefined;
    }

    this.running = true;
    this.timerId = setInterval(() => {
      if (this.listener !== undefined) {
        this.listener(this.calc.result());
      }
    }, this.opt.emitIntervalMs);
    return true;
  }

  stop(): void {
    if (!this.running) {
      return;
    }
    this.running = false;

    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.baroHandler !== undefined) {
      try {
        sensor.off(sensor.SensorId.BAROMETER, this.baroHandler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop barometer ${e.code}: ${e.message}`);
      }
      this.baroHandler = undefined;
    }
    if (this.accelHandler !== undefined) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER, this.accelHandler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop accelerometer ${e.code}: ${e.message}`);
      }
      this.accelHandler = undefined;
    }
    this.listener = undefined;
  }

  pause(): void {
    this.calc.pause();
  }

  resume(): void {
    this.calc.resume();
  }

  reset(): void {
    this.calc.reset();
  }

  snapshot(): ClimbData {
    return this.calc.result();
  }

  startRecording(): void {
    this.calc.startRecording();
  }

  stopRecording(): string {
    return this.calc.stopRecording();
  }

  saveRecording(context: common.UIAbilityContext): string {
    const csv: string = this.calc.stopRecording();
    if (csv.length === 0) {
      return '';
    }
    const path: string = `${context.filesDir}/climb_${Date.now()}.csv`;
    try {
      const file = fileIo.openSync(path,
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(file.fd, csv);
      fileIo.closeSync(file);
      this.log.i(`recording saved: ${path}`);
      return path;
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`could not write recording ${e.code}: ${e.message}`);
      return '';
    }
  }
}
