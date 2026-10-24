// ============================================================
// calculate-route-score
// OSRM alternatif rotalarını Supabase erişilebilirlik verileriyle
// puanlar ve en yüksek puanlı rotayı döndürür.
// ============================================================

import {
  createClient,
  type SupabaseClient,
} from 'npm:@supabase/supabase-js@2';

const OSRM_BASE_URL = 'https://router.project-osrm.org/route/v1/foot';
const OSRM_TIMEOUT_MS = 20_000;
const OSRM_ALTERNATIVES = '3';
const NEARBY_RADIUS_METERS = 100;
const BOUNDING_BOX_PADDING_DEGREES = 0.001;
const ACTIVE_REPORT_STATUSES = ['pending', 'validated'] as const;
const REPORT_QUERY_BATCH_SIZE = 150;

/**
 * Rapor başlığındaki anahtar kelimeye göre tam erişilebilirlik cezası.
 * Başlık küçük harfe çevrilip `includes` ile aranır; böylece
 * "Bozuk Kaldırım", "bozuk kaldırım" ve "kaldırım" aynı cezayı alır.
 * İlk eşleşen kural uygulanır.
 */
const REPORT_PENALTIES: ReadonlyArray<readonly [string, number]> = [
  ['kaldırım', 15],
  ['rampa', 20],
  ['geçiş', 10],
  ['asansör', 15],
];

const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type GeoCoordinate = [longitude: number, latitude: number];

interface RouteRequest {
  startLat: number;
  startLng: number;
  endLat: number;
  endLng: number;
}

interface Point {
  latitude: number;
  longitude: number;
}

interface BoundingBox {
  minLatitude: number;
  maxLatitude: number;
  minLongitude: number;
  maxLongitude: number;
}

interface LocationRow {
  id: string;
  latitude: number | string | null;
  longitude: number | string | null;
}

interface ReportRow {
  title: string | null;
  location_id: string;
  status: string | null;
}

interface OsrmRoute {
  distance?: number;
  bbox?: number[];
  geometry?: {
    coordinates?: unknown;
  };
}

interface OsrmResponse {
  code?: string;
  message?: string;
  routes?: OsrmRoute[];
}

interface RouteCandidate {
  coordinates: GeoCoordinate[];
  pathPoints: Point[];
  distance: number;
  bounds: BoundingBox;
}

interface ScoredRoute extends RouteCandidate {
  score: number;
  obstacleCount: number;
}

class RouteFunctionError extends Error {
  readonly status: number;

  constructor(status: number, message: string) {
    super(message);
    this.name = 'RouteFunctionError';
    this.status = status;
  }
}

Deno.serve(async (request: Request): Promise<Response> => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }

  if (request.method !== 'POST') {
    return jsonResponse(
      { error: 'Yalnızca POST istekleri desteklenir' },
      405,
    );
  }

  try {
    let rawBody: unknown;
    try {
      rawBody = await request.json();
    } catch {
      throw new RouteFunctionError(400, 'Geçersiz JSON gövdesi');
    }

    const routeRequest = parseRouteRequest(rawBody);
    const osrmRoutes = await fetchOsrmRoutes(routeRequest);
    console.log(`OSRM'den ${osrmRoutes.length} rota alındı`);

    const routeCandidates = parseRouteCandidates(osrmRoutes);
    const paddedBoundingBox = mergeBoundingBoxes(
      routeCandidates.map((route) => route.bounds),
    );
    console.log(
      `Bounding Box: minLat=${paddedBoundingBox.minLatitude}, ` +
        `maxLat=${paddedBoundingBox.maxLatitude}, ` +
        `minLng=${paddedBoundingBox.minLongitude}, ` +
        `maxLng=${paddedBoundingBox.maxLongitude}`,
    );

    const supabase = createSupabaseClient();
    const locationsById = await fetchNearbyLocations(
      supabase,
      paddedBoundingBox,
    );
    console.log(`Fetched locations in bbox: ${locationsById.size}`);

    const reports: ReportRow[] =
      locationsById.size === 0
        ? []
        : await fetchActiveReports(
            supabase,
            Array.from(locationsById.keys()),
          );
    console.log(`Fetched reports for these locations: ${reports.length}`);

    const scoredRoutes: ScoredRoute[] = routeCandidates.map((route) => {
      const result = scoreRoute(route, reports, locationsById);

      return {
        ...route,
        score: result.score,
        obstacleCount: result.obstacleCount,
      };
    });

    for (const [index, route] of scoredRoutes.entries()) {
      console.log(
        `Rota ${index + 1}: mesafe=${route.distance.toFixed(1)} m, ` +
          `puan=${route.score.toFixed(1)}, engel=${route.obstacleCount}`,
      );
    }

    // Ürün kararı: Erişilebilirlik mesafeden daha önemlidir. Bu yüzden en
    // yüksek puanlı rota seçilir; yalnızca puanlar eşitse en kısa rota tercih
    // edilir.
    const bestRoute = selectBestRoute(scoredRoutes);
    console.log(
      `Seçilen rota: puan=${bestRoute.score.toFixed(1)}, ` +
        `mesafe=${bestRoute.distance.toFixed(1)} m`,
    );

    return jsonResponse(
      {
        geometry: bestRoute.coordinates,
        distance: bestRoute.distance,
        score: bestRoute.score,
      },
      200,
    );
  } catch (error) {
    if (error instanceof RouteFunctionError) {
      return jsonResponse({ error: error.message }, error.status);
    }

    console.error('calculate-route-score unexpected error', error);
    return jsonResponse(
      { error: 'Rota hesaplanırken beklenmeyen bir hata oluştu' },
      500,
    );
  }
});

// ============================================================
// İSTEK DOĞRULAMA
// ============================================================

function parseRouteRequest(value: unknown): RouteRequest {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new RouteFunctionError(400, 'İstek gövdesi bir JSON nesnesi olmalıdır');
  }

  const body = value as Record<string, unknown>;
  const startLat = asFiniteNumber(body.startLat);
  const startLng = asFiniteNumber(body.startLng);
  const endLat = asFiniteNumber(body.endLat);
  const endLng = asFiniteNumber(body.endLng);

  if (
    startLat === null ||
    startLng === null ||
    endLat === null ||
    endLng === null
  ) {
    throw new RouteFunctionError(
      400,
      'startLat, startLng, endLat ve endLng sayısal olmalıdır',
    );
  }

  if (
    startLat < -90 ||
    startLat > 90 ||
    endLat < -90 ||
    endLat > 90 ||
    startLng < -180 ||
    startLng > 180 ||
    endLng < -180 ||
    endLng > 180
  ) {
    throw new RouteFunctionError(400, 'Koordinatlar geçerli aralıkta değil');
  }

  return { startLat, startLng, endLat, endLng };
}

// ============================================================
// OSRM
// ============================================================

async function fetchOsrmRoutes(
  routeRequest: RouteRequest,
): Promise<OsrmRoute[]> {
  const coordinatePath =
    `${routeRequest.startLng},${routeRequest.startLat};` +
    `${routeRequest.endLng},${routeRequest.endLat}`;
  const url = new URL(`${OSRM_BASE_URL}/${coordinatePath}`);
  url.searchParams.set('alternatives', OSRM_ALTERNATIVES);
  url.searchParams.set('overview', 'full');
  url.searchParams.set('geometries', 'geojson');

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), OSRM_TIMEOUT_MS);

  let response: Response;
  try {
    response = await fetch(url, {
      headers: { Accept: 'application/json' },
      signal: controller.signal,
    });
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new RouteFunctionError(504, 'Rota servisi zaman aşımına uğradı');
    }

    throw new RouteFunctionError(502, 'Rota servisine ulaşılamadı');
  } finally {
    clearTimeout(timeoutId);
  }

  if (!response.ok) {
    throw new RouteFunctionError(
      502,
      `Rota servisi ${response.status} yanıtı döndürdü`,
    );
  }

  let payload: OsrmResponse;
  try {
    payload = (await response.json()) as OsrmResponse;
  } catch {
    throw new RouteFunctionError(502, 'Rota servisi geçersiz yanıt döndürdü');
  }

  const routes = Array.isArray(payload.routes)
    ? payload.routes.filter(
        (route): route is OsrmRoute =>
          typeof route === 'object' && route !== null && !Array.isArray(route),
      )
    : [];

  if (
    typeof payload.code !== 'string' ||
    payload.code.toLowerCase() !== 'ok' ||
    routes.length === 0
  ) {
    throw new RouteFunctionError(
      502,
      payload.message ?? 'Rota bulunamadı',
    );
  }

  return routes;
}

function parseGeometry(value: unknown): GeoCoordinate[] {
  if (!Array.isArray(value)) {
    throw new RouteFunctionError(502, 'Rota geometrisi bulunamadı');
  }

  const coordinates: GeoCoordinate[] = [];

  for (const item of value) {
    if (!Array.isArray(item) || item.length < 2) continue;

    // OSRM GeoJSON sırası: [longitude, latitude]
    const longitude = asFiniteNumber(item[0]);
    const latitude = asFiniteNumber(item[1]);

    if (
      longitude === null ||
      latitude === null ||
      longitude < -180 ||
      longitude > 180 ||
      latitude < -90 ||
      latitude > 90
    ) {
      continue;
    }

    coordinates.push([longitude, latitude]);
  }

  if (coordinates.length === 0) {
    throw new RouteFunctionError(502, 'Rota geometrisi geçersiz');
  }

  return coordinates;
}

function parseDistance(value: unknown): number {
  const distance = asFiniteNumber(value);

  if (distance === null || distance < 0) {
    throw new RouteFunctionError(502, 'Rota mesafesi geçersiz');
  }

  return distance;
}

/**
 * OSRM'nin döndürdüğü alternatifleri puanlamaya hazırlar.
 * Geçersiz bir alternatif tüm isteği düşürmesin diye yalnızca o rota atlanır.
 */
function parseRouteCandidates(routes: OsrmRoute[]): RouteCandidate[] {
  const candidates: RouteCandidate[] = [];

  for (const [index, route] of routes.entries()) {
    try {
      const coordinates = parseGeometry(route.geometry?.coordinates);
      const distance = parseDistance(route.distance);
      const bounds = resolveBoundingBox(route.bbox, coordinates);
      const pathPoints = coordinates.map(([longitude, latitude]) => ({
        latitude,
        longitude,
      }));

      candidates.push({ coordinates, pathPoints, distance, bounds });
    } catch (error) {
      console.error(`OSRM alternatif rota ${index + 1} atlandı`, error);
    }
  }

  if (candidates.length === 0) {
    throw new RouteFunctionError(502, 'Geçerli rota bulunamadı');
  }

  return candidates;
}

// ============================================================
// SUPABASE SORGULARI
// ============================================================

function createSupabaseClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  // Service role anahtarı yalnızca sunucu tarafındaki Supabase istemcisinde
  // kullanılır; yanıta veya loglara asla eklenmez.
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    throw new RouteFunctionError(500, 'Sunucu yapılandırması eksik');
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

async function fetchNearbyLocations(
  supabase: SupabaseClient,
  bounds: BoundingBox,
): Promise<Map<string, Point>> {
  const { data, error } = await supabase
    .from('locations')
    .select('id, latitude, longitude')
    .gte('latitude', bounds.minLatitude)
    .lte('latitude', bounds.maxLatitude)
    .gte('longitude', bounds.minLongitude)
    .lte('longitude', bounds.maxLongitude);

  if (error) {
    console.error('locations query failed', error);
    throw new RouteFunctionError(500, 'Konum verileri alınamadı');
  }

  const locationsById = new Map<string, Point>();

  for (const row of (data ?? []) as LocationRow[]) {
    if (typeof row.id !== 'string') continue;

    const latitude = asFiniteNumber(row.latitude);
    const longitude = asFiniteNumber(row.longitude);

    if (latitude === null || longitude === null) continue;

    locationsById.set(row.id, { latitude, longitude });
  }

  return locationsById;
}

async function fetchActiveReports(
  supabase: SupabaseClient,
  locationIds: string[],
): Promise<ReportRow[]> {
  const reports: ReportRow[] = [];

  for (
    let index = 0;
    index < locationIds.length;
    index += REPORT_QUERY_BATCH_SIZE
  ) {
    const batch = locationIds.slice(index, index + REPORT_QUERY_BATCH_SIZE);

    const { data, error } = await supabase
      .from('reports')
      .select('title, location_id, status')
      .in('location_id', batch)
      .in('status', [...ACTIVE_REPORT_STATUSES]);

    if (error) {
      console.error('reports query failed', error);
      throw new RouteFunctionError(500, 'Rapor verileri alınamadı');
    }

    reports.push(...((data ?? []) as ReportRow[]));
  }

  return reports;
}

// ============================================================
// PUANLAMA VE MESAFE HESABI
// ============================================================

function penaltyForReport(title: string | null): number {
  const normalizedTitle = (title ?? '').trim().toLowerCase();

  for (const [keyword, penalty] of REPORT_PENALTIES) {
    if (normalizedTitle.includes(keyword)) return penalty;
  }

  return 0;
}

/**
 * Doğrulanmış raporlar tam ceza uygular; bekleyen raporların cezası yarıya
 * indirilir. Bilinmeyen bir durum için ceza uygulanmaz.
 */
function penaltyMultiplierForStatus(status: string | null): number {
  switch ((status ?? '').trim().toLowerCase()) {
    case 'validated':
      return 1;
    case 'pending':
      return 0.5;
    default:
      return 0;
  }
}

function scoreRoute(
  route: RouteCandidate,
  reports: ReportRow[],
  locationsById: Map<string, Point>,
): { score: number; obstacleCount: number } {
  let score = 100;
  let obstacleCount = 0;

  for (const report of reports) {
    const location = locationsById.get(report.location_id);
    if (!location) continue;

    const distance = distanceToPathInMeters(location, route.pathPoints);
    if (distance > NEARBY_RADIUS_METERS) continue;

    obstacleCount++;
    console.log(
      `Found obstacle: ${report.title ?? 'Bilinmeyen'}, ` +
        `distance: ${distance.toFixed(1)}m`,
    );

    const fullPenalty = penaltyForReport(report.title);
    const multiplier = penaltyMultiplierForStatus(report.status);

    if (fullPenalty === 0 || multiplier === 0) continue;

    score -= fullPenalty * multiplier;
  }

  return {
    score: Math.max(0, Math.min(100, score)),
    obstacleCount,
  };
}

function selectBestRoute(routes: ScoredRoute[]): ScoredRoute {
  let bestRoute = routes[0];

  for (let index = 1; index < routes.length; index++) {
    const route = routes[index];

    if (
      route.score > bestRoute.score ||
      (route.score === bestRoute.score &&
        route.distance < bestRoute.distance)
    ) {
      bestRoute = route;
    }
  }

  return bestRoute;
}

function distanceToPathInMeters(
  point: Point,
  pathPoints: Point[],
): number {
  if (pathPoints.length === 0) return Number.POSITIVE_INFINITY;

  if (pathPoints.length === 1) {
    return haversineDistanceInMeters(point, pathPoints[0]);
  }

  // Yalnızca köşe noktalarına bakmak uzun düz segmentlerde yakındaki
  // noktaları kaçırabilir; her segment için en yakın noktayı hesapla.
  let shortestDistance = Number.POSITIVE_INFINITY;

  for (let index = 0; index < pathPoints.length - 1; index++) {
    const nearestPoint = nearestPointOnSegment(
      point,
      pathPoints[index],
      pathPoints[index + 1],
    );
    const distance = haversineDistanceInMeters(point, nearestPoint);

    if (distance < shortestDistance) {
      shortestDistance = distance;
    }
  }

  return shortestDistance;
}

/**
 * [point] noktasının [start]-[end] segmentine en yakın noktasını döndürür.
 *
 * 100 m'lik mesafelerde yeterince doğru olan yerel düzlem yaklaşımı kullanır;
 * nihai mesafe hesabı Haversine formülüyle yapılır.
 */
function nearestPointOnSegment(
  point: Point,
  start: Point,
  end: Point,
): Point {
  const metersPerDegreeLatitude = 111320;
  const metersPerDegreeLongitude =
    metersPerDegreeLatitude * Math.abs(Math.cos(toRadians(point.latitude)));

  if (metersPerDegreeLongitude < 0.000001) return start;

  const startX =
    (start.longitude - point.longitude) * metersPerDegreeLongitude;
  const startY =
    (start.latitude - point.latitude) * metersPerDegreeLatitude;
  const endX = (end.longitude - point.longitude) * metersPerDegreeLongitude;
  const endY = (end.latitude - point.latitude) * metersPerDegreeLatitude;

  const segmentX = endX - startX;
  const segmentY = endY - startY;
  const segmentLengthSquared = segmentX * segmentX + segmentY * segmentY;

  if (segmentLengthSquared === 0) return start;

  const projection = Math.max(
    0,
    Math.min(
      1,
      -(startX * segmentX + startY * segmentY) / segmentLengthSquared,
    ),
  );

  const nearestX = startX + projection * segmentX;
  const nearestY = startY + projection * segmentY;

  return {
    latitude: point.latitude + nearestY / metersPerDegreeLatitude,
    longitude: point.longitude + nearestX / metersPerDegreeLongitude,
  };
}

function haversineDistanceInMeters(from: Point, to: Point): number {
  const earthRadiusInMeters = 6371000;

  const latitudeDelta = toRadians(to.latitude - from.latitude);
  const longitudeDelta = toRadians(to.longitude - from.longitude);
  const fromLatitude = toRadians(from.latitude);
  const toLatitude = toRadians(to.latitude);

  const sinLatitude = Math.sin(latitudeDelta / 2);
  const sinLongitude = Math.sin(longitudeDelta / 2);

  const a =
    sinLatitude * sinLatitude +
    Math.cos(fromLatitude) *
      Math.cos(toLatitude) *
      sinLongitude *
      sinLongitude;

  return (
    2 *
    earthRadiusInMeters *
    Math.asin(Math.sqrt(Math.min(1, Math.max(0, a))))
  );
}

function toRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}

// ============================================================
// SINIR KUTUSU
// ============================================================

function mergeBoundingBoxes(boxes: BoundingBox[]): BoundingBox {
  if (boxes.length === 0) {
    throw new RouteFunctionError(502, 'Rota sınırları bulunamadı');
  }

  let merged = boxes[0];

  for (let index = 1; index < boxes.length; index++) {
    const box = boxes[index];

    merged = {
      minLatitude: Math.min(merged.minLatitude, box.minLatitude),
      maxLatitude: Math.max(merged.maxLatitude, box.maxLatitude),
      minLongitude: Math.min(merged.minLongitude, box.minLongitude),
      maxLongitude: Math.max(merged.maxLongitude, box.maxLongitude),
    };
  }

  return merged;
}

function resolveBoundingBox(
  routeBbox: unknown,
  coordinates: GeoCoordinate[],
): BoundingBox {
  let bounds = boundingBoxFromCoordinates(coordinates);

  if (Array.isArray(routeBbox) && routeBbox.length >= 4) {
    const minLongitude = asFiniteNumber(routeBbox[0]);
    const minLatitude = asFiniteNumber(routeBbox[1]);
    const maxLongitude = asFiniteNumber(routeBbox[2]);
    const maxLatitude = asFiniteNumber(routeBbox[3]);

    if (
      minLongitude !== null &&
      minLatitude !== null &&
      maxLongitude !== null &&
      maxLatitude !== null &&
      minLongitude >= -180 &&
      maxLongitude <= 180 &&
      minLatitude >= -90 &&
      maxLatitude <= 90 &&
      minLongitude <= maxLongitude &&
      minLatitude <= maxLatitude
    ) {
      bounds = {
        minLatitude,
        maxLatitude,
        minLongitude,
        maxLongitude,
      };
    }
  }

  return {
    minLatitude: Math.max(
      -90,
      bounds.minLatitude - BOUNDING_BOX_PADDING_DEGREES,
    ),
    maxLatitude: Math.min(
      90,
      bounds.maxLatitude + BOUNDING_BOX_PADDING_DEGREES,
    ),
    minLongitude: Math.max(
      -180,
      bounds.minLongitude - BOUNDING_BOX_PADDING_DEGREES,
    ),
    maxLongitude: Math.min(
      180,
      bounds.maxLongitude + BOUNDING_BOX_PADDING_DEGREES,
    ),
  };
}

function boundingBoxFromCoordinates(
  coordinates: GeoCoordinate[],
): BoundingBox {
  let minLatitude = coordinates[0][1];
  let maxLatitude = coordinates[0][1];
  let minLongitude = coordinates[0][0];
  let maxLongitude = coordinates[0][0];

  for (const [longitude, latitude] of coordinates) {
    if (latitude < minLatitude) minLatitude = latitude;
    if (latitude > maxLatitude) maxLatitude = latitude;
    if (longitude < minLongitude) minLongitude = longitude;
    if (longitude > maxLongitude) maxLongitude = longitude;
  }

  return { minLatitude, maxLatitude, minLongitude, maxLongitude };
}

// ============================================================
// YARDIMCI FONKSİYONLAR
// ============================================================

function asFiniteNumber(value: unknown): number | null {
  if (typeof value === 'number' && Number.isFinite(value)) return value;

  if (typeof value === 'string' && value.trim() !== '') {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }

  return null;
}

function jsonResponse(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      'Content-Type': 'application/json; charset=utf-8',
    },
  });
}
