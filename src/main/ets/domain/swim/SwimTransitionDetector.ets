import { T_MU, T_SD, T1_W, T1_S, T1_B, T2_W, T2_S, T2_B, T3_W, T3_S, T3_B, T4_W, T4_S, T4_B } from './SwimTransitionData';

class QLayer {
  q: Int8Array;
  scale: Float32Array;
  bias: Float32Array;
  constructor(q: Int8Array, scale: Float32Array, bias: Float32Array) {
    this.q = q;
    this.scale = scale;
    this.bias = bias;
  }
}

class TransModel {
  mu: Float32Array = new Float32Array(6);
  sd: Float32Array = new Float32Array(6);
  layers: QLayer[] = [];
}

export class SwimTransitionDetector {
  private static readonly RATE_HZ: number = 30;
  private static readonly WIN: number = 60;
  private static readonly STEP: number = 15;
  private static readonly C1: number = 16;
  private static readonly C2: number = 24;
  private static readonly C3: number = 24;

  private static model: TransModel | undefined = undefined;
  private static bufIn: Float32Array = new Float32Array(60 * 6);
  private static bufC1: Float32Array = new Float32Array(60 * 16);
  private static bufP1: Float32Array = new Float32Array(30 * 16);
  private static bufC2: Float32Array = new Float32Array(30 * 24);
  private static bufP2: Float32Array = new Float32Array(15 * 24);
  private static bufC3: Float32Array = new Float32Array(15 * 24);
  private static acc: Float64Array = new Float64Array(24);
  private static gap: Float64Array = new Float64Array(24);

  private ring: Float32Array = new Float32Array(60 * 6);
  private head: number = 0;
  private filled: number = 0;
  private sinceLast: number = 0;
  private lastProb: number = -1;
  private lastTimeMs: number = 0;

  private prevT: number = -1;
  private prev: Float64Array = new Float64Array(6);
  private cur: Float64Array = new Float64Array(6);
  private nextEmit: number = 0;

  constructor() {
    SwimTransitionDetector.ensureModel();
  }

  onSample(ax: number, ay: number, az: number, gx: number, gy: number, gz: number, tMs: number): number {
    const c: Float64Array = this.cur;
    c[0] = ax; c[1] = ay; c[2] = az; c[3] = gx; c[4] = gy; c[5] = gz;
    if (this.prevT < 0) {
      this.prevT = tMs;
      this.prev.set(c);
      this.nextEmit = tMs;
    }
    let produced: number = -1;
    const period: number = 1000 / SwimTransitionDetector.RATE_HZ;
    while (this.nextEmit <= tMs) {
      const span: number = tMs - this.prevT;
      const a: number = span > 0 ? (this.nextEmit - this.prevT) / span : 1;
      const base: number = this.head * 6;
      for (let i = 0; i < 6; i++) {
        this.ring[base + i] = this.prev[i] + (c[i] - this.prev[i]) * a;
      }
      this.head = (this.head + 1) % SwimTransitionDetector.WIN;
      if (this.filled < SwimTransitionDetector.WIN) {
        this.filled++;
      }
      this.sinceLast++;
      if (this.filled === SwimTransitionDetector.WIN && this.sinceLast >= SwimTransitionDetector.STEP) {
        this.sinceLast = 0;
        const inp: Float32Array = SwimTransitionDetector.bufIn;
        for (let t = 0; t < SwimTransitionDetector.WIN; t++) {
          const src: number = ((this.head + t) % SwimTransitionDetector.WIN) * 6;
          for (let i = 0; i < 6; i++) {
            inp[t * 6 + i] = this.ring[src + i];
          }
        }
        this.lastProb = SwimTransitionDetector.forwardFlat(inp);
        this.lastTimeMs = this.nextEmit;
        produced = this.lastProb;
      }
      this.nextEmit += period;
    }
    this.prevT = tMs;
    this.prev.set(c);
    return produced;
  }

  probability(): number {
    return this.lastProb;
  }

  timeOfLastMs(): number {
    return this.lastTimeMs;
  }

  reset(): void {
    this.head = 0;
    this.filled = 0;
    this.sinceLast = 0;
    this.lastProb = -1;
    this.prevT = -1;
  }

  static forward(raw: number[][]): number {
    SwimTransitionDetector.ensureModel();
    const inp: Float32Array = SwimTransitionDetector.bufIn;
    for (let t = 0; t < 60; t++) {
      for (let i = 0; i < 6; i++) {
        inp[t * 6 + i] = raw[t][i];
      }
    }
    return SwimTransitionDetector.forwardFlat(inp);
  }

  private static forwardFlat(inp: Float32Array): number {
    const m: TransModel = SwimTransitionDetector.model as TransModel;
    for (let t = 0; t < 60; t++) {
      for (let i = 0; i < 6; i++) {
        inp[t * 6 + i] = (inp[t * 6 + i] - m.mu[i]) / m.sd[i];
      }
    }
    SwimTransitionDetector.convRelu(inp, 60, 6, m.layers[0], 16, SwimTransitionDetector.bufC1);
    SwimTransitionDetector.pool(SwimTransitionDetector.bufC1, 60, 16, SwimTransitionDetector.bufP1);
    SwimTransitionDetector.convRelu(SwimTransitionDetector.bufP1, 30, 16, m.layers[1], 24, SwimTransitionDetector.bufC2);
    SwimTransitionDetector.pool(SwimTransitionDetector.bufC2, 30, 24, SwimTransitionDetector.bufP2);
    SwimTransitionDetector.convRelu(SwimTransitionDetector.bufP2, 15, 24, m.layers[2], 24, SwimTransitionDetector.bufC3);

    const g: Float64Array = SwimTransitionDetector.gap;
    for (let o = 0; o < 24; o++) {
      let s: number = 0;
      for (let t = 0; t < 15; t++) {
        s += SwimTransitionDetector.bufC3[t * 24 + o];
      }
      g[o] = s / 15;
    }
    const d: QLayer = m.layers[3];
    const z: number[] = [0, 0];
    for (let o = 0; o < 2; o++) {
      let s: number = 0;
      for (let i = 0; i < 24; i++) {
        s += g[i] * d.q[i * 2 + o];
      }
      z[o] = d.bias[o] + d.scale[o] * s;
    }
    const zmax: number = z[0] > z[1] ? z[0] : z[1];
    const e0: number = Math.exp(z[0] - zmax);
    const e1: number = Math.exp(z[1] - zmax);
    return e1 / (e0 + e1);
  }

  private static convRelu(x: Float32Array, L: number, IN: number, layer: QLayer, OUT: number, y: Float32Array): void {
    const K: number = 5;
    const pad: number = 2;
    const acc: Float64Array = SwimTransitionDetector.acc;
    const q: Int8Array = layer.q;
    for (let t = 0; t < L; t++) {
      for (let o = 0; o < OUT; o++) {
        acc[o] = 0;
      }
      for (let k = 0; k < K; k++) {
        const src: number = t + k - pad;
        if (src < 0 || src >= L) {
          continue;
        }
        const xBase: number = src * IN;
        const kBase: number = k * IN * OUT;
        for (let i = 0; i < IN; i++) {
          const v: number = x[xBase + i];
          if (v === 0) {
            continue;
          }
          const wBase: number = kBase + i * OUT;
          for (let o = 0; o < OUT; o++) {
            acc[o] += v * q[wBase + o];
          }
        }
      }
      const yBase: number = t * OUT;
      for (let o = 0; o < OUT; o++) {
        const val: number = layer.bias[o] + layer.scale[o] * acc[o];
        y[yBase + o] = val > 0 ? val : 0;
      }
    }
  }

  private static pool(x: Float32Array, L: number, C: number, y: Float32Array): void {
    const n: number = Math.floor(L / 2);
    for (let t = 0; t < n; t++) {
      const a: number = 2 * t * C;
      const b: number = a + C;
      for (let o = 0; o < C; o++) {
        const va: number = x[a + o];
        const vb: number = x[b + o];
        y[t * C + o] = va > vb ? va : vb;
      }
    }
  }

  private static ensureModel(): void {
    if (SwimTransitionDetector.model !== undefined) {
      return;
    }
    const m: TransModel = new TransModel();
    m.mu = SwimTransitionDetector.toF32(T_MU);
    m.sd = SwimTransitionDetector.toF32(T_SD);
    m.layers.push(SwimTransitionDetector.makeLayer(T1_W, T1_S, T1_B));
    m.layers.push(SwimTransitionDetector.makeLayer(T2_W, T2_S, T2_B));
    m.layers.push(SwimTransitionDetector.makeLayer(T3_W, T3_S, T3_B));
    m.layers.push(SwimTransitionDetector.makeLayer(T4_W, T4_S, T4_B));
    SwimTransitionDetector.model = m;
  }

  private static makeLayer(w: number[], s: number[], b: number[]): QLayer {
    const q: Int8Array = new Int8Array(w.length);
    for (let i = 0; i < w.length; i++) {
      q[i] = w[i];
    }
    return new QLayer(q, SwimTransitionDetector.toF32(s), SwimTransitionDetector.toF32(b));
  }

  private static toF32(a: number[]): Float32Array {
    const r: Float32Array = new Float32Array(a.length);
    for (let i = 0; i < a.length; i++) {
      r[i] = a[i];
    }
    return r;
  }

}
