import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../util/Logger';

export class GyroscopeSource {
  private handler: ((data: sensor.GyroscopeResponse) => void) | undefined = undefined;
  private log: Logger = new Logger('GyroscopeSource');

  start(cb: (x: number, y: number, z: number) => void): void {
    this.stop();
    this.handler = (data: sensor.GyroscopeResponse) => {
      cb(data.x, data.y, data.z);
    };
    try {
      sensor.on(sensor.SensorId.GYROSCOPE, this.handler, { interval: 20000000 });
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`gyroscope unavailable ${e.code}: ${e.message}`);
      this.handler = undefined;
    }
  }

  stop(): void {
    if (this.handler !== undefined) {
      try {
        sensor.off(sensor.SensorId.GYROSCOPE, this.handler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop gyroscope ${e.code}: ${e.message}`);
      }
      this.handler = undefined;
    }
  }
}
