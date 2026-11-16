import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../util/Logger';

export class AccelerometerSource {
  private handler: ((data: sensor.AccelerometerResponse) => void) | undefined = undefined;
  private log: Logger = new Logger('AccelerometerSource');

  start(cb: (x: number, y: number, z: number, timeMs: number) => void): void {
    this.stop();
    this.handler = (data: sensor.AccelerometerResponse) => {
      cb(data.x, data.y, data.z, Date.now());
    };
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, this.handler, { interval: 20000000 });
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`accelerometer unavailable ${e.code}: ${e.message}`);
      this.handler = undefined;
    }
  }

  stop(): void {
    if (this.handler !== undefined) {
      try {
        sensor.off(sensor.SensorId.ACCELEROMETER, this.handler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop accelerometer ${e.code}: ${e.message}`);
      }
      this.handler = undefined;
    }
  }
}
