import { distanceMeters as haversineMeters } from '../GeoMath';

export class RoutePoint {
  latitude: number = 0;
  longitude: number = 0;
  timestamp: number = 0;
  altitude: number = 0;

  constructor(lat: number, lon: number, t: number, alt: number) {
    this.latitude = lat;
    this.longitude = lon;
    this.timestamp = t;
    this.altitude = alt;
  }
}

export class RouteRecorder {
  private static readonly MIN_STEP_METERS: number = 0.5;
  private minDistanceM: number;
  private minAngleDeg: number;
  private maxPoints: number;

  private segments: RoutePoint[][] = [];
  private current: RoutePoint[] = [];
  private lastHeading: number = -1;
  private total: number = 0;

  constructor(minDistanceM: number, minAngleDeg: number, maxPoints: number) {
    this.minDistanceM = minDistanceM;
    this.minAngleDeg = minAngleDeg;
    this.maxPoints = maxPoints;
  }

  onPoint(lat: number, lon: number, timestamp: number, altitude: number): void {
    if (this.current.length === 0) {
      this.push(new RoutePoint(lat, lon, timestamp, altitude));
      return;
    }

    const last: RoutePoint = this.current[this.current.length - 1];
    const d: number = haversineMeters(last.latitude, last.longitude, lat, lon);
    if (d < RouteRecorder.MIN_STEP_METERS) {
      return;
    }

    const heading: number = RouteRecorder.bearingDegrees(last.latitude, last.longitude, lat, lon);
    let turned: boolean = false;
    if (this.lastHeading >= 0) {
      const diff: number = Math.abs(RouteRecorder.angleDiff(this.lastHeading, heading));
      turned = diff >= this.minAngleDeg;
    }

    if (d >= this.minDistanceM || turned) {
      this.push(new RoutePoint(lat, lon, timestamp, altitude));
      this.lastHeading = heading;
    }
  }

  breakSegment(): void {
    if (this.current.length > 0) {
      this.segments.push(this.current);
      this.current = [];
      this.lastHeading = -1;
    }
  }

  finish(): void {
    this.breakSegment();
  }

  segmentCount(): number {
    return this.segments.length + (this.current.length > 0 ? 1 : 0);
  }

  pointCount(): number {
    return this.total;
  }

  route(): RoutePoint[][] {
    const out: RoutePoint[][] = [];
    for (const segment of this.segments) {
      out.push(segment);
    }
    if (this.current.length > 0) {
      out.push(this.current);
    }
    return out;
  }

  simplified(toleranceM: number): RoutePoint[][] {
    const out: RoutePoint[][] = [];
    for (const segment of this.route()) {
      out.push(RouteRecorder.douglasPeucker(segment, toleranceM));
    }
    return out;
  }

  reset(): void {
    this.segments = [];
    this.current = [];
    this.lastHeading = -1;
    this.total = 0;
  }

  static encodePolyline(points: RoutePoint[]): string {
    let out: string = '';
    let prevLat: number = 0;
    let prevLon: number = 0;

    for (const p of points) {
      const lat: number = Math.round(p.latitude * 1e5);
      const lon: number = Math.round(p.longitude * 1e5);
      out += RouteRecorder.encodeValue(lat - prevLat);
      out += RouteRecorder.encodeValue(lon - prevLon);
      prevLat = lat;
      prevLon = lon;
    }
    return out;
  }

  private push(p: RoutePoint): void {
    this.current.push(p);
    this.total++;
    if (this.total > this.maxPoints) {
      this.thin();
    }
  }

  private thin(): void {
    let n: number = 0;
    const segments: RoutePoint[][] = [];

    for (const segment of this.segments) {
      const thinned: RoutePoint[] = RouteRecorder.dropEveryOther(segment);
      n += thinned.length;
      segments.push(thinned);
    }

    this.segments = segments;
    this.current = RouteRecorder.dropEveryOther(this.current);
    this.total = n + this.current.length;
    this.minDistanceM = this.minDistanceM * 2;
  }

  private static dropEveryOther(segment: RoutePoint[]): RoutePoint[] {
    if (segment.length <= 2) {
      return segment;
    }
    const out: RoutePoint[] = [];
    for (let i = 0; i < segment.length; i++) {
      if (i === 0 || i === segment.length - 1 || i % 2 === 0) {
        out.push(segment[i]);
      }
    }
    return out;
  }

  private static douglasPeucker(points: RoutePoint[], toleranceM: number): RoutePoint[] {
    if (points.length <= 2) {
      return points;
    }
    let maxDist: number = 0;
    let index: number = 0;

    for (let i = 1; i < points.length - 1; i++) {
      const d: number = RouteRecorder.perpDistance(points[i], points[0], points[points.length - 1]);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (maxDist <= toleranceM) {
      return [points[0], points[points.length - 1]];
    }

    const left: RoutePoint[] = RouteRecorder.douglasPeucker(points.slice(0, index + 1), toleranceM);
    const right: RoutePoint[] = RouteRecorder.douglasPeucker(points.slice(index), toleranceM);
    const out: RoutePoint[] = [];
    for (let i = 0; i < left.length - 1; i++) {
      out.push(left[i]);
    }
    for (const p of right) {
      out.push(p);
    }
    return out;
  }

  private static perpDistance(p: RoutePoint, a: RoutePoint, b: RoutePoint): number {
    const mPerDegLat: number = 111320;
    const mPerDegLon: number = 111320 * Math.cos(a.latitude * Math.PI / 180);
    const px: number = (p.longitude - a.longitude) * mPerDegLon;
    const py: number = (p.latitude - a.latitude) * mPerDegLat;
    const bx: number = (b.longitude - a.longitude) * mPerDegLon;
    const by: number = (b.latitude - a.latitude) * mPerDegLat;

    const len2: number = bx * bx + by * by;
    if (len2 === 0) {
      return Math.sqrt(px * px + py * py);
    }

    let t: number = (px * bx + py * by) / len2;
    if (t < 0) {
      t = 0;
    } else if (t > 1) {
      t = 1;
    }

    const dx: number = px - t * bx;
    const dy: number = py - t * by;
    return Math.sqrt(dx * dx + dy * dy);
  }

  private static bearingDegrees(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const toRad: number = Math.PI / 180;
    const p1: number = lat1 * toRad;
    const p2: number = lat2 * toRad;
    const dl: number = (lon2 - lon1) * toRad;
    const y: number = Math.sin(dl) * Math.cos(p2);
    const x: number = Math.cos(p1) * Math.sin(p2) - Math.sin(p1) * Math.cos(p2) * Math.cos(dl);
    const deg: number = Math.atan2(y, x) * 180 / Math.PI;
    return ((deg % 360) + 360) % 360;
  }

  private static angleDiff(from: number, to: number): number {
    return ((to - from + 540) % 360) - 180;
  }

  private static encodeValue(value: number): string {
    let x: number = value < 0 ? ~(value << 1) : (value << 1);
    let out: string = '';
    while (x >= 0x20) {
      out += String.fromCharCode((0x20 | (x & 0x1f)) + 63);
      x = x >> 5;
    }
    out += String.fromCharCode(x + 63);
    return out;
  }
}
