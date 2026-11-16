import { NORM_MU, NORM_SD, C1_W, C1_B, C2_W, C2_B, C3_W, C3_B, D_W, D_B } from './weight/SwimCnnWeights';

export class SwimStyleCnn {
  private static readonly RATE_HZ: number = 30;
  private static readonly WIN: number = 90;
  private static readonly STEP: number = 45;
  private static readonly VOTE_SIZE: number = 5;

  private window: number[][] = [];
  private sinceLast: number = 0;
  private votes: number[] = [];
  private style: number = -1;
  private lastProbs: number[] = [0, 0, 0, 0, 0];

  private prevT: number = -1;
  private prev: number[] = [0, 0, 0, 0, 0, 0];
  private nextEmit: number = 0;

  onSample(ax: number, ay: number, az: number, gx: number, gy: number, gz: number, tMs: number): void {
    const cur: number[] = [ax, ay, az, gx, gy, gz];
    if (this.prevT < 0) {
      this.prevT = tMs;
      this.prev = cur;
      this.nextEmit = tMs;
    }
    const period: number = 1000 / SwimStyleCnn.RATE_HZ;
    while (this.nextEmit <= tMs) {
      const span: number = tMs - this.prevT;
      const a: number = span > 0 ? (this.nextEmit - this.prevT) / span : 1;
      const s: number[] = [];
      for (let i = 0; i < 6; i++) {
        s.push(this.prev[i] + (cur[i] - this.prev[i]) * a);
      }
      this.push30(s);
      this.nextEmit += period;
    }
    this.prevT = tMs;
    this.prev = cur;
  }

  currentStyle(): number {
    return this.style;
  }

  probabilities(): number[] {
    return this.lastProbs;
  }

  reset(): void {
    this.window = [];
    this.sinceLast = 0;
    this.votes = [];
    this.style = -1;
    this.lastProbs = [0, 0, 0, 0, 0];
    this.prevT = -1;
  }

  private push30(s: number[]): void {
    this.window.push(s);
    if (this.window.length > SwimStyleCnn.WIN) {
      this.window.shift();
    }
    this.sinceLast++;
    if (this.window.length === SwimStyleCnn.WIN && this.sinceLast >= SwimStyleCnn.STEP) {
      this.sinceLast = 0;
      this.lastProbs = SwimStyleCnn.forward(this.window);
      let best: number = 0;
      for (let i = 1; i < 5; i++) {
        if (this.lastProbs[i] > this.lastProbs[best]) {
          best = i;
        }
      }
      this.votes.push(best);
      if (this.votes.length > SwimStyleCnn.VOTE_SIZE) {
        this.votes.shift();
      }
      const c: number[] = [0, 0, 0, 0, 0];
      for (const v of this.votes) {
        c[v]++;
      }
      let top: number = 0;
      for (let i = 1; i < 5; i++) {
        if (c[i] > c[top]) {
          top = i;
        }
      }
      this.style = top;
    }
  }

  static forward(raw: number[][]): number[] {
    const L: number = raw.length;
    const x: number[][] = [];
    for (let t = 0; t < L; t++) {
      const r: number[] = [];
      for (let i = 0; i < 6; i++) {
        r.push((raw[t][i] - NORM_MU[i]) / NORM_SD[i]);
      }
      x.push(r);
    }
    let h: number[][] = SwimStyleCnn.pool(SwimStyleCnn.convRelu(x, C1_W, C1_B, 6, 32));
    h = SwimStyleCnn.pool(SwimStyleCnn.convRelu(h, C2_W, C2_B, 32, 64));
    h = SwimStyleCnn.convRelu(h, C3_W, C3_B, 64, 64);

    const g: number[] = [];
    for (let o = 0; o < 64; o++) {
      let s: number = 0;
      for (let t = 0; t < h.length; t++) {
        s += h[t][o];
      }
      g.push(s / h.length);
    }

    const z: number[] = [];
    let zmax: number = -Number.MAX_VALUE;
    for (let o = 0; o < 5; o++) {
      let s: number = D_B[o];
      for (let i = 0; i < 64; i++) {
        s += g[i] * D_W[i * 5 + o];
      }
      z.push(s);
      if (s > zmax) {
        zmax = s;
      }
    }
    let sum: number = 0;
    const p: number[] = [];
    for (let o = 0; o < 5; o++) {
      const e: number = Math.exp(z[o] - zmax);
      p.push(e);
      sum += e;
    }
    for (let o = 0; o < 5; o++) {
      p[o] = p[o] / sum;
    }
    return p;
  }

  private static convRelu(x: number[][], W: number[], B: number[], IN: number, OUT: number): number[][] {
    const L: number = x.length;
    const K: number = 5;
    const pad: number = 2;
    const y: number[][] = [];
    for (let t = 0; t < L; t++) {
      const row: number[] = [];
      for (let o = 0; o < OUT; o++) {
        row.push(B[o]);
      }
      for (let k = 0; k < K; k++) {
        const src: number = t + k - pad;
        if (src < 0 || src >= L) {
          continue;
        }
        const xs: number[] = x[src];
        const kBase: number = k * IN * OUT;
        for (let i = 0; i < IN; i++) {
          const v: number = xs[i];
          if (v === 0) {
            continue;
          }
          const base: number = kBase + i * OUT;
          for (let o = 0; o < OUT; o++) {
            row[o] += v * W[base + o];
          }
        }
      }
      for (let o = 0; o < OUT; o++) {
        if (row[o] < 0) {
          row[o] = 0;
        }
      }
      y.push(row);
    }
    return y;
  }

  private static pool(x: number[][]): number[][] {
    const n: number = Math.floor(x.length / 2);
    const y: number[][] = [];
    for (let t = 0; t < n; t++) {
      const a: number[] = x[2 * t];
      const b: number[] = x[2 * t + 1];
      const r: number[] = [];
      for (let o = 0; o < a.length; o++) {
        r.push(a[o] > b[o] ? a[o] : b[o]);
      }
      y.push(r);
    }
    return y;
  }
}
