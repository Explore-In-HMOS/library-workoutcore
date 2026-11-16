import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../util/Logger';

export class HRSource {
  private callback: ((count: number) => void) | undefined = undefined;
  private handler: ((data: sensor.HeartRateResponse) => void) | undefined = undefined;
  private log: Logger = new Logger('HRSource');

  start(cb: (count: number) => void): void {
    this.stop();
    this.callback = cb;

    this.handler = (data: sensor.HeartRateResponse) => {
      if (this.callback !== undefined) {
        this.callback(data.heartRate);
      }
    };

    try {
      sensor.on(sensor.SensorId.HEART_RATE, this.handler);
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`heart rate unavailable ${e.code}: ${e.message}`);
      this.handler = undefined;
      this.callback = undefined;
    }
  }

  stop(): void {
    if (this.handler !== undefined) {
      try {
        sensor.off(sensor.SensorId.HEART_RATE, this.handler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop heart rate ${e.code}: ${e.message}`);
      }
      this.handler = undefined;
    }
    this.callback = undefined;
  }
}
