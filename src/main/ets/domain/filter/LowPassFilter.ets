export class LowPassFilter {
  private alpha: number;
  private value: number = 0;
  private initialized: boolean = false;

  constructor(cutoffHz: number, sampleRateHz: number) {
    const dt: number = 1 / sampleRateHz;
    const rc: number = 1 / (2 * Math.PI * cutoffHz);
    this.alpha = dt / (rc + dt);
  }

  filter(x: number): number {
    if (!this.initialized) {
      this.value = x;
      this.initialized = true;
      return x;
    }
    this.value = this.value + this.alpha * (x - this.value);
    return this.value;
  }

  reset(): void {
    this.initialized = false;
    this.value = 0;
  }
}