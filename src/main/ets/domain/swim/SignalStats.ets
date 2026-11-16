export class SignalStats {
  private minV: number = Number.MAX_VALUE;
  private maxV: number = -Number.MAX_VALUE;
  private sum: number = 0;
  private sumSq: number = 0;
  private n: number = 0;

  add(v: number): void {
    if (v < this.minV) { this.minV = v; }
    if (v > this.maxV) { this.maxV = v; }
    this.sum += v;
    this.sumSq += v * v;
    this.n++;
  }

  summary(): string {
    if (this.n === 0) {
      return 'no data';
    }
    const mean: number = this.sum / this.n;
    const variance: number = this.sumSq / this.n - mean * mean;
    const std: number = Math.sqrt(Math.max(variance, 0));
    return `min: ${this.minV.toFixed(2)}  max: ${this.maxV.toFixed(2)}  mean: ${mean.toFixed(2)}  std: ${std.toFixed(2)}  samples: ${this.n}`;
  }

  reset(): void {
    this.minV = Number.MAX_VALUE;
    this.maxV = -Number.MAX_VALUE;
    this.sum = 0;
    this.sumSq = 0;
    this.n = 0;
  }
}