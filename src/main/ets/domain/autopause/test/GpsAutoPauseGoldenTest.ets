import { AutoPauseOptions, PauseState } from '../../../models/AutoPauseTypes';
import { GpsAutoPause } from '../GpsAutoPause';

class Step {
  tMs: number = 0;
  speedMps: number = 0;
  accuracyM: number = 5;
  manualPause: boolean = false;
  manualResume: boolean = false;
  expected: PauseState = PauseState.ACTIVE;
}

class Scenario {
  name: string = '';
  opt: AutoPauseOptions = {
    pauseSpeedMps: 0.5,
    resumeSpeedMps: 0.8,
    pauseDelayMs: 5000,
    resumeDelayMs: 2000,
    minGpsAccuracyM: 50,
    maxPointAgeMs: 10000
  };
  steps: Step[] = [];
}

function step(tMs: number, speedMps: number, expected: PauseState): Step {
  const s: Step = new Step();
  s.tMs = tMs;
  s.speedMps = speedMps;
  s.expected = expected;
  return s;
}

function badFix(tMs: number, speedMps: number, accuracyM: number, expected: PauseState): Step {
  const s: Step = step(tMs, speedMps, expected);
  s.accuracyM = accuracyM;
  return s;
}

function manual(tMs: number, speedMps: number, pause: boolean, expected: PauseState): Step {
  const s: Step = step(tMs, speedMps, expected);
  s.manualPause = pause;
  s.manualResume = !pause;
  return s;
}

const ACT: PauseState = PauseState.ACTIVE;
const AUTO: PauseState = PauseState.AUTO_PAUSED;
const MAN: PauseState = PauseState.MANUAL_PAUSED;

const CASES: Scenario[] = [
  {
    // Slow speed lasting pauseDelayMs starts auto-pause.
    name: 'slow_pause',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      step(1000, 0.1, ACT),
      step(2000, 0.1, ACT),
      step(3000, 0.1, ACT),
      step(4000, 0.1, ACT),
      step(5000, 0.1, ACT),
      step(6000, 0.1, AUTO)   // 5000 ms of slow speed
    ]
  },
  {
    // A brief slowdown spike does not accumulate dwell -> no early pause.
    name: 'short_slowdown_no_flap',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      step(1000, 0.1, ACT),
      step(2000, 0.1, ACT),
      step(3000, 3.0, ACT),   // dwell reset
      step(4000, 0.1, ACT),
      step(5000, 0.1, ACT),   // 2000 ms slow in total -> still no pause
      step(6000, 3.0, ACT)
    ]
  },
  {
    // In the dead band (between thresholds) the state is kept; resume needs resumeDelayMs.
    name: 'dead_band_state_kept',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      step(1000, 0.65, ACT),  // dead band
      step(2000, 0.65, ACT),
      step(3000, 0.65, ACT),
      step(4000, 0.1, ACT),
      step(9000, 0.1, AUTO),
      step(10000, 0.65, AUTO), // dead band does not clear the pause
      step(11000, 0.65, AUTO),
      step(12000, 0.9, AUTO),  // fast candidate started
      step(14000, 0.9, ACT)    // resumeDelayMs elapsed
    ]
  },
  {
    // Unknown speed (-1) is ignored: it neither pauses nor resets dwell.
    name: 'invalid_speed_ignored',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      step(1000, 0.1, ACT),
      step(2000, 0.1, ACT),
      step(3000, -1.0, ACT),  // unknown -> transparent
      step(4000, 0.1, ACT),
      step(6000, 0.1, AUTO)   // slow since 1000 ms
    ]
  },
  {
    // Bad accuracy is ignored: a fast bad fix does not clear the pause.
    name: 'bad_accuracy_ignored',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      step(1000, 0.1, ACT),
      step(2000, 0.1, ACT),
      badFix(3000, 3.0, 200, ACT),  // bad fix, ignored
      step(4000, 0.1, ACT),
      step(6000, 0.1, AUTO)
    ]
  },
  {
    // A GPS gap longer than maxPointAgeMs resets the dwell counters.
    name: 'gps_gap_resets_dwell',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      step(1000, 0.1, ACT),
      step(2000, 0.1, ACT),
      step(3000, 0.1, ACT),
      step(20000, 0.1, ACT),  // 17000 ms gap -> dwell reset
      step(24000, 0.1, ACT),
      step(25000, 0.1, AUTO)
    ]
  },
  {
    // Automatic logic cannot clear a manual pause; it runs again after release.
    name: 'manual_pause_not_cleared_automatically',
    opt: {
      pauseSpeedMps: 0.5, resumeSpeedMps: 0.8,
      pauseDelayMs: 5000, resumeDelayMs: 2000,
      minGpsAccuracyM: 50, maxPointAgeMs: 10000
    },
    steps: [
      step(0, 3.0, ACT),
      manual(1000, 3.0, true, MAN),
      step(2000, 3.0, MAN),      // stays manual even at high speed
      step(5000, 3.0, MAN),
      manual(6000, 3.0, false, ACT),
      step(7000, 0.1, ACT),      // dwell starts from zero
      step(11000, 0.1, ACT),
      step(12000, 0.1, AUTO)
    ]
  }
];

export function runGpsAutoPauseGoldenTest(): void {
  for (const c of CASES) {
    const ap: GpsAutoPause = new GpsAutoPause(c.opt);
    let firstFail: string = '';
    for (const s of c.steps) {
      if (s.manualPause) {
        ap.manualPause();
      } else if (s.manualResume) {
        ap.manualResume();
      }
      ap.onSpeed(s.speedMps, s.accuracyM, s.tMs);
      const got: PauseState = ap.state();
      if (got !== s.expected && firstFail.length === 0) {
        firstFail = `t=${s.tMs} speed=${s.speedMps} expected=${s.expected} got=${got}`;
      }
    }
    const ok: boolean = firstFail.length === 0;
    console.info(`AUTOPAUSE GOLDEN ${c.name}: ${ok ? 'PASS' : 'FAIL'}${ok ? '' : '  ' + firstFail}`);
  }
}
