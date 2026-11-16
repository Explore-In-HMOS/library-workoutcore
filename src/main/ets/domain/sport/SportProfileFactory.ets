import { SportType } from "../../models/TrackingTypes";
import { CyclingProfile } from "./CyclingProfile";
import { IndoorRunProfile } from "./IndoorRunProfile";
import { RunningProfile } from "./RunningProfile";
import { SportProfile } from "./SportProfile";
import { SwimmingProfile } from "./SwimmingProfile";
import { WaterSportsProfile } from './WaterSportsProfile';

export class SportProfileFactory {

  private static readonly registry: Map<SportType, () => SportProfile> = new Map([
    [SportType.RUNNING, () => new RunningProfile()],
    [SportType.WALKING, () => new RunningProfile()],
    [SportType.INDOOR_RUN, () => new IndoorRunProfile()],
    [SportType.CYCLING, () => new CyclingProfile()],
    [SportType.SWIMMING, () => new SwimmingProfile()],
    [SportType.WATER_SPORTS, () => new WaterSportsProfile()]
  ]);

  static create(type: SportType): SportProfile {
    const factory = SportProfileFactory.registry.get(type);

    if (factory === undefined) {
      throw new Error(`Unsupported sport type: ${type}`);
    }
    return factory();
  }
}