import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../util/Logger';

export class StepSource {
  private callback: ((count: number) => void) | undefined = undefined;
  private handler: ((data: sensor.PedometerResponse) => void) | undefined = undefined;
  private log: Logger = new Logger('StepSource');

  start(cb: (count: number) => void): void {
    this.stop();
    this.callback = cb;

    this.handler = (data: sensor.PedometerResponse) => {
      if (this.callback !== undefined) {
        this.callback(data.steps);
      }
    };

    try {
      sensor.on(sensor.SensorId.PEDOMETER, this.handler);
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`pedometer unavailable ${e.code}: ${e.message}`);
      this.handler = undefined;
      this.callback = undefined;
    }
  }

  stop(): void {
    if (this.handler !== undefined) {
      try {
        sensor.off(sensor.SensorId.PEDOMETER, this.handler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop pedometer ${e.code}: ${e.message}`);
      }
      this.handler = undefined;
    }
    this.callback = undefined;
  }
}
