import { FilteredSpeedResult, SpeedFilterOptions, defaultSpeedFilterOptions } from '../../../models/SpeedFilterTypes';
import { ISpeedFilterStrategy } from '../ISpeedFilterStrategy';
import { KalmanSpeedFilter } from '../KalmanFilter';
import { PassThroughSpeedFilter } from '../PassThroughFilter';

class Sample {
  speedMps: number = 0.0;
  accuracyM: number = 5.0;
  dtSeconds: number = 1.0;
}

class Scenario {
  name: string = '';
  kalman: boolean = true;
  options: SpeedFilterOptions = defaultSpeedFilterOptions();
  samples: Sample[] = [];
  // Expectations; a negative value means no check.
  expectFinalMinMps: number = -1.0;
  expectFinalMaxMps: number = -1.0;
  expectMaxOutputMps: number = -1.0;
  expectStdRatioBelow: number = -1.0;   // filtered std / raw std
  expectAnySpikeClamped: boolean = false;
}

function sample(speedMps: number, dtSeconds: number): Sample {
  const s: Sample = new Sample();
  s.speedMps = speedMps;
  s.dtSeconds = dtSeconds;
  return s;
}

function flat(speedMps: number, count: number): Sample[] {
  const out: Sample[] = [];
  for (let i = 0; i < count; i++) {
    out.push(sample(speedMps, 1.0));
  }
  return out;
}

const NOISE_PATTERN: number[] = [1.2, -0.6, 0.9, -1.2, 0.3, -0.9, 1.1, -0.3];

function noiseSamples(): Sample[] {
  const out: Sample[] = [];
  for (let i = 0; i < 24; i++) {
    out.push(sample(3.0 + NOISE_PATTERN[i % NOISE_PATTERN.length], 1.0));
  }
  return out;
}

function stdDev(values: number[]): number {
  if (values.length === 0) {
    return 0.0;
  }
  let sum: number = 0.0;
  for (const v of values) {
    sum += v;
  }
  const mean: number = sum / values.length;
  let acc: number = 0.0;
  for (const v of values) {
    acc += (v - mean) * (v - mean);
  }
  return Math.sqrt(acc / values.length);
}

function createFilter(kalman: boolean, options: SpeedFilterOptions): ISpeedFilterStrategy {
  return kalman ? new KalmanSpeedFilter(options) : new PassThroughSpeedFilter(options);
}

const CASES: Scenario[] = [
  {
    // Steady run + GPS noise: output stays in the real speed band and is smoother than raw.
    name: 'noise_suppression',
    kalman: true,
    options: defaultSpeedFilterOptions(),
    samples: noiseSamples(),
    expectFinalMinMps: 2.4,
    expectFinalMaxMps: 3.6,
    expectMaxOutputMps: -1.0,
    // Filtered std must stay below raw std; with Kalman off the ratio approaches 1.
    expectStdRatioBelow: 0.9,
    expectAnySpikeClamped: false
  },
  {
    // A single 40 m/s spike must not drag the estimate along.
    name: 'spike_suppression',
    kalman: true,
    options: defaultSpeedFilterOptions(),
    samples: flat(3.0, 10).concat([sample(40.0, 1.0)], flat(3.0, 5)),
    expectFinalMinMps: 2.4,
    expectFinalMaxMps: 3.6,
    expectMaxOutputMps: 4.0,
    expectStdRatioBelow: -1.0,
    expectAnySpikeClamped: true
  },
  {
    // Residual speed while standing still must lock to zero.
    name: 'standstill_clamp',
    kalman: true,
    options: defaultSpeedFilterOptions(),
    samples: flat(3.0, 10).concat(flat(0.05, 12)),
    expectFinalMinMps: -1.0,
    expectFinalMaxMps: 0.0,
    expectMaxOutputMps: -1.0,
    expectStdRatioBelow: -1.0,
    expectAnySpikeClamped: false
  },
  {
    // After a long GPS gap the filter must restart instead of predicting through it.
    name: 'long_gap_reinit',
    kalman: true,
    options: defaultSpeedFilterOptions(),
    samples: flat(3.0, 5).concat([sample(8.0, 60.0)]),
    expectFinalMinMps: 7.0,
    expectFinalMaxMps: -1.0,
    expectMaxOutputMps: -1.0,
    expectStdRatioBelow: -1.0,
    expectAnySpikeClamped: false
  },
  {
    // Unknown speed (-1) must be ignored without disturbing the state (same rule as GpsAutoPause).
    name: 'negative_speed_ignored',
    kalman: true,
    options: defaultSpeedFilterOptions(),
    samples: flat(3.0, 5).concat([sample(-1.0, 1.0)]),
    expectFinalMinMps: 2.4,
    expectFinalMaxMps: 3.6,
    expectMaxOutputMps: -1.0,
    expectStdRatioBelow: -1.0,
    expectAnySpikeClamped: false
  },
  {
    // Kalman off: the physical limit is applied and flagged.
    name: 'passthrough_limit',
    kalman: false,
    options: defaultSpeedFilterOptions(),
    samples: [sample(50.0, 1.0)],
    expectFinalMinMps: 12.5,
    expectFinalMaxMps: 12.5,
    expectMaxOutputMps: 12.5,
    expectStdRatioBelow: -1.0,
    expectAnySpikeClamped: true
  },
  {
    // Kalman off: negative/unknown speed is clamped to zero.
    name: 'passthrough_negative_zero',
    kalman: false,
    options: defaultSpeedFilterOptions(),
    samples: [sample(-1.0, 1.0)],
    expectFinalMinMps: -1.0,
    expectFinalMaxMps: 0.0,
    expectMaxOutputMps: 0.0,
    expectStdRatioBelow: -1.0,
    expectAnySpikeClamped: false
  }
];

function check(c: Scenario, outputs: number[], anySpike: boolean): string {
  if (outputs.length === 0) {
    return 'no samples';
  }

  const final: number = outputs[outputs.length - 1];
  if (c.expectFinalMinMps >= 0.0 && final < c.expectFinalMinMps) {
    return `final=${final.toFixed(3)} expected min=${c.expectFinalMinMps}`;
  }
  if (c.expectFinalMaxMps >= 0.0 && final > c.expectFinalMaxMps) {
    return `final=${final.toFixed(3)} expected max=${c.expectFinalMaxMps}`;
  }

  let maxOutput: number = outputs[0];
  for (const v of outputs) {
    if (v > maxOutput) {
      maxOutput = v;
    }
  }
  if (c.expectMaxOutputMps >= 0.0 && maxOutput > c.expectMaxOutputMps) {
    return `max output=${maxOutput.toFixed(3)} expected max=${c.expectMaxOutputMps}`;
  }

  if (c.expectStdRatioBelow >= 0.0) {
    const tail: number[] = outputs.slice(Math.max(0, outputs.length - 10));
    const rawTail: number[] = [];
    for (let i = Math.max(0, c.samples.length - 10); i < c.samples.length; i++) {
      rawTail.push(c.samples[i].speedMps);
    }
    const rawStd: number = stdDev(rawTail);
    if (rawStd > 0.0) {
      const ratio: number = stdDev(tail) / rawStd;
      if (ratio >= c.expectStdRatioBelow) {
        return `std ratio=${ratio.toFixed(3)} expected < ${c.expectStdRatioBelow}`;
      }
    }
  }

  if (c.expectAnySpikeClamped && !anySpike) {
    return 'spike was not flagged';
  }

  return '';
}

export function runSpeedFilterGoldenTest(): void {
  for (const c of CASES) {
    const filter: ISpeedFilterStrategy = createFilter(c.kalman, c.options);
    const outputs: number[] = [];
    let anySpike: boolean = false;
    for (const s of c.samples) {
      const r: FilteredSpeedResult = filter.process(s.speedMps, s.accuracyM, s.dtSeconds);
      outputs.push(r.speedMps);
      anySpike = anySpike || r.isSpikeClamped;
    }
    const fail: string = check(c, outputs, anySpike);
    const ok: boolean = fail.length === 0;
    console.info(`FILTER GOLDEN ${c.name}: ${ok ? 'PASS' : 'FAIL'}${ok ? '' : '  ' + fail}`);
  }
}
