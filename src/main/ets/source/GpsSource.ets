import { geoLocationManager } from '@kit.LocationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { TrackPoint } from '../models/TrackingListener';
import { Logger } from '../util/Logger';

export class GpsSource {
  private callback: ((p: TrackPoint) => void) | undefined = undefined;
  private handler: ((loc: geoLocationManager.Location) => void) | undefined = undefined;
  private log: Logger = new Logger('GpsSource');

  start(intervalMs: number, cb: (p: TrackPoint) => void): void {
    this.stop();
    this.callback = cb;

    const request: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.ACCURACY,
      scenario: geoLocationManager.LocationRequestScenario.NAVIGATION,
      timeInterval: Math.floor(intervalMs / 1000),
      distanceInterval: 0,
      maxAccuracy: 0
    };

    this.handler = (loc: geoLocationManager.Location) => {
      const p: TrackPoint = {
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracy: loc.accuracy,
        speed: loc.speed,
        timestamp: loc.timeStamp,
        altitude: loc.altitude,
        direction: loc.direction
      };
      if (this.callback !== undefined) {
        this.callback(p);
      }
    };

    try {
      geoLocationManager.on('locationChange', request, this.handler);
    } catch (err) {
      const e = err as BusinessError;
      this.log.e(`location unavailable ${e.code}: ${e.message}`);
      this.handler = undefined;
      this.callback = undefined;
    }
  }

  stop(): void {
    if (this.handler !== undefined) {
      try {
        geoLocationManager.off('locationChange', this.handler);
      } catch (err) {
        const e = err as BusinessError;
        this.log.w(`could not stop location updates ${e.code}: ${e.message}`);
      }
      this.handler = undefined;
    }
    this.callback = undefined;
  }
}
