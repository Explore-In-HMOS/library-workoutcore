export function distanceMeters(
  lat1: number, lon1: number,
  lat2: number, lon2: number
): number {
  const EARTH_RADIUS_M: number = 6371000;
  const toRad: number = Math.PI / 180;

  const dLat: number = (lat2 - lat1) * toRad;
  const dLon: number = (lon2 - lon1) * toRad;

  const a: number =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * toRad) * Math.cos(lat2 * toRad) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);

  return EARTH_RADIUS_M * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}
