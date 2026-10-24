// ============================================================
// map_page.dart
// Ana harita ekranı (MapLibre + 3D binalar + bildirim işaretleri)
// ============================================================

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/domain/entities/report_entity.dart';
import '../../../reports/presentation/providers/report_provider.dart';
import '../../../reports/presentation/report_categories.dart';
import '../../../reports/presentation/widgets/create_report_sheet.dart';
import '../../../reports/presentation/widgets/report_detail_sheet.dart';
import '../../../route/presentation/providers/route_provider.dart';
import '../../../route/presentation/widgets/navigation_sheet.dart';
import '../widgets/map_search_bar.dart';

class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  // Bartın merkez koordinatları
  static const LatLng _bartinCenter = LatLng(41.6378, 32.3374);
  static const String _mapStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';
  static const String _selectedLocationIconId = 'selected-location';
  static const String _routeLineId = 'accessible-route';
  static const String _heatmapSourceId = 'report-density-source';
  static const String _heatmapLayerId = 'report-density-layer';
  static const double _reportMarkerImageSize = 96;
  static const double _reportMarkerIconSize = 0.46;
  static const Color _routeColor = Color(0xFF2196F3);
  static const Color _destinationColor = Color(0xFF4CAF50);
  static const String _destinationColorHex = '#4CAF50';

  MapLibreMapController? _mapController;
  SymbolManager? _reportSymbolManager;
  SymbolManager? _selectionSymbolManager;
  CircleManager? _destinationCircleManager;
  LineManager? _routeLineManager;
  OnFeatureInteractionCallback? _featureTapCallback;
  final Map<String, ReportEntity> _reportsById = <String, ReportEntity>{};

  LatLng? _selectedLocation;
  LatLng? _selectedDestination;
  LatLng? _navigationStart;
  LatLng? _currentGpsLocation;
  bool _styleLoaded = false;
  bool _annotationsInitialized = false;
  bool _customIconsLoaded = false;
  bool _showHeatmap = false;
  bool _heatmapSourceAdded = false;
  bool _heatmapLayerAdded = false;
  bool _isSelectingDestination = false;
  bool _isNavigationSheetOpen = false;
  bool _isResolvingNavigationStart = false;
  bool _isReportDetailOpen = false;
  int _reportSyncRequest = 0;
  int _selectionSyncRequest = 0;
  int _destinationSyncRequest = 0;
  int _routeSyncRequest = 0;
  Future<void> _heatmapOperations = Future<void>.value();
  DateTime? _lastMapControlInteractionAt;

  @override
  void initState() {
    super.initState();
    // İlk frame'den sonra yakındaki bildirimleri yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(reportControllerProvider.notifier)
          .loadNearbyReports(_bartinCenter.latitude, _bartinCenter.longitude);
    });
  }

  @override
  void dispose() {
    final controller = _mapController;
    final callback = _featureTapCallback;
    if (controller != null && !controller.isDisposed && callback != null) {
      controller.onFeatureTapped.remove(callback);
    }
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    // Ayrı oluşturulan işaret katmanları controller'ın yerleşik
    // manager'ında olmadığı için onSymbolTapped yerine generic callback kullanılır.
    _featureTapCallback = (point, coordinates, id, layerId, annotation) {
      _handleFeatureTapped(id);
    };
    controller.onFeatureTapped.add(_featureTapCallback!);

    if (_styleLoaded) {
      unawaited(_initializeAnnotations());
      if (_showHeatmap) {
        _scheduleHeatmapSync();
      }
    }
  }

  void _handleFeatureTapped(String id) {
    if (!mounted) return;

    final report = _reportsById[id];
    if (report == null) return;

    // Hedef seçimi sırasında bildirim işareti de hedef noktası olarak kullanılabilir.
    if (_isSelectingDestination) {
      _handleDestinationSelected(LatLng(report.latitude, report.longitude));
      return;
    }

    unawaited(_showReportDetailSheet(report));
  }

  Future<void> _showReportDetailSheet(ReportEntity report) async {
    if (!mounted || _isReportDetailOpen) return;

    _isReportDetailOpen = true;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        builder: (_) => ReportDetailSheet(report: report),
      );
    } finally {
      _isReportDetailOpen = false;
    }
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    // Yeni stil yüklendiğinde önceki heatmap kaynak/katman referansları geçersizdir.
    _heatmapSourceAdded = false;
    _heatmapLayerAdded = false;
    unawaited(_initializeAnnotations());
    if (_showHeatmap) {
      _scheduleHeatmapSync();
    }
  }

  // Admin heatmap girişi MVP kapsamında gizlendi. Katman altyapısı ileride
  // yeniden etkinleştirilebilmesi için korunuyor.
  // ignore: unused_element
  void _toggleHeatmap() {
    setState(() {
      _showHeatmap = !_showHeatmap;
    });
    _scheduleHeatmapSync();
  }

  void _scheduleHeatmapSync() {
    _heatmapOperations = _heatmapOperations.then((_) async {
      try {
        await _syncHeatmap();
      } catch (error) {
        debugPrint('Isı haritası işlemi başarısız: $error');
      }
    });
  }

  Future<void> _syncHeatmap() async {
    if (!mounted) return;

    final controller = _mapController;
    if (controller == null || controller.isDisposed || !_styleLoaded) {
      return;
    }

    if (!_showHeatmap) {
      await _removeHeatmap(controller);
      return;
    }

    final geoJson = _buildHeatmapGeoJson();

    try {
      if (_heatmapSourceAdded) {
        await controller.setGeoJsonSource(_heatmapSourceId, geoJson);
      } else {
        await controller.addSource(
          _heatmapSourceId,
          GeojsonSourceProperties(data: geoJson),
        );
        _heatmapSourceAdded = true;
      }

      if (_heatmapLayerAdded) return;

      await controller.addLayer(
        _heatmapSourceId,
        _heatmapLayerId,
        const HeatmapLayerProperties(
          heatmapRadius: 40,
          heatmapIntensity: 1.2,
          heatmapOpacity: 0.75,
        ),
      );
      _heatmapLayerAdded = true;
    } catch (error) {
      debugPrint('Isı haritası güncellenemedi: $error');
    }
  }

  Future<void> _removeHeatmap(MapLibreMapController controller) async {
    try {
      if (_heatmapLayerAdded) {
        await controller.removeLayer(_heatmapLayerId);
        _heatmapLayerAdded = false;
      }
    } catch (error) {
      debugPrint('Isı haritası katmanı kaldırılamadı: $error');
    }

    try {
      if (_heatmapSourceAdded) {
        await controller.removeSource(_heatmapSourceId);
        _heatmapSourceAdded = false;
      }
    } catch (error) {
      debugPrint('Isı haritası kaynağı kaldırılamadı: $error');
    }
  }

  Map<String, dynamic> _buildHeatmapGeoJson() {
    final state = ref.read(reportControllerProvider);
    final reports =
        state is ReportLoaded ? state.reports : const <ReportEntity>[];

    final features = reports
        .where((report) => report.latitude != 0 || report.longitude != 0)
        .map(
          (report) => <String, dynamic>{
            'type': 'Feature',
            'geometry': <String, dynamic>{
              'type': 'Point',
              'coordinates': <double>[report.longitude, report.latitude],
            },
            'properties': <String, dynamic>{
              'report_id': report.id,
              'title': report.title,
            },
          },
        )
        .toList(growable: false);

    return <String, dynamic>{'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _initializeAnnotations() async {
    if (_annotationsInitialized) return;

    final controller = _mapController;
    if (controller == null || controller.isDisposed) return;

    _annotationsInitialized = true;

    try {
      await _loadCustomIcons(controller);
    } catch (error) {
      debugPrint('Harita simge görselleri yüklenemedi: $error');
    }

    if (!mounted || controller.isDisposed) return;

    final reportSymbols = SymbolManager(
      controller,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      enableInteraction: true,
    );
    final selectionSymbols = SymbolManager(
      controller,
      iconAllowOverlap: true,
      iconIgnorePlacement: true,
      enableInteraction: false,
    );
    final destinationCircles = CircleManager(
      controller,
      enableInteraction: false,
    );
    final routeLines = LineManager(controller, enableInteraction: false);

    try {
      // Çizgi katmanı işaretlerin altında kalsın diye önce başlatılır.
      await routeLines.initialize();
      await reportSymbols.initialize();
      await selectionSymbols.initialize();
      await destinationCircles.initialize();
    } catch (error) {
      debugPrint('Harita katmanları oluşturulamadı: $error');
      return;
    }

    if (!mounted || controller.isDisposed) return;

    _reportSymbolManager = reportSymbols;
    _selectionSymbolManager = selectionSymbols;
    _destinationCircleManager = destinationCircles;
    _routeLineManager = routeLines;

    await _syncReportMarkers();
    await _syncSelectionSymbol();
    await _syncDestinationMarker();
    await _syncRouteLine();
  }

  Future<void> _loadCustomIcons(MapLibreMapController controller) async {
    try {
      final selectedData = await rootBundle.load(
        'assets/icons/selected_location.png',
      );

      await controller.addImage(
        _selectedLocationIconId,
        selectedData.buffer.asUint8List(),
      );

      _customIconsLoaded = true;
    } catch (error) {
      debugPrint('Seçili konum simgesi yüklenemedi: $error');
    }

    // Kategori ikonlarını cihazda üretip MapLibre görsel kayıtlarına ekle.
    for (final category in ReportCategory.values) {
      try {
        final bytes = await _generateReportMarkerIcon(
          icon: category.icon,
          color: category.color,
        );
        await controller.addImage(category.markerIconId, bytes);
      } catch (error) {
        debugPrint('${category.label} işaret simgesi yüklenemedi: $error');
      }
    }
  }

  Future<Uint8List> _generateReportMarkerIcon({
    required IconData icon,
    required Color color,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(
      _reportMarkerImageSize / 2,
      _reportMarkerImageSize / 2,
    );

    // Harita üzerinde işareti zeminden ayıran hafif gölge.
    canvas.drawCircle(
      center.translate(0, 2),
      41,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Beyaz dış çerçeve ve kategori rengindeki gövde.
    canvas.drawCircle(center, 40, Paint()..color = Colors.white);
    canvas.drawCircle(center, 33, Paint()..color = color);

    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          fontSize: 42,
          height: 1,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    iconPainter.paint(
      canvas,
      Offset(
        center.dx - iconPainter.width / 2,
        center.dy - iconPainter.height / 2,
      ),
    );

    final image = await recorder.endRecording().toImage(
      _reportMarkerImageSize.toInt(),
      _reportMarkerImageSize.toInt(),
    );

    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('İşaret simgesi PNG verisine dönüştürülemedi');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  }

  Future<void> _syncReportMarkers() async {
    final manager = _reportSymbolManager;
    if (manager == null || !manager.isInitialized) return;
    if (manager.controller.isDisposed) return;

    final request = ++_reportSyncRequest;
    final state = ref.read(reportControllerProvider);
    final reports =
        state is ReportLoaded ? state.reports : const <ReportEntity>[];

    await manager.clear();
    if (request != _reportSyncRequest) return;

    final symbols = <Symbol>[];
    final reportsById = <String, ReportEntity>{};

    for (var i = 0; i < reports.length; i++) {
      final report = reports[i];

      // Konumu olmayan kayıtları haritada göstermeyelim.
      if (report.latitude == 0 && report.longitude == 0) continue;

      final markerId = 'report-${report.id.isEmpty ? i : report.id}';
      reportsById[markerId] = report;

      symbols.add(
        Symbol(
          markerId,
          SymbolOptions(
            geometry: LatLng(report.latitude, report.longitude),
            iconImage: ReportCategory.forTitle(report.title).markerIconId,
            iconSize: _reportMarkerIconSize,
            iconAnchor: 'center',
          ),
        ),
      );
    }

    if (request != _reportSyncRequest) return;

    _reportsById
      ..clear()
      ..addAll(reportsById);

    if (symbols.isNotEmpty) {
      await manager.addAll(symbols);
    }
  }

  Future<void> _syncSelectionSymbol() async {
    final manager = _selectionSymbolManager;
    if (manager == null || !manager.isInitialized) return;

    final request = ++_selectionSyncRequest;
    await manager.clear();
    if (request != _selectionSyncRequest) return;

    final location = _selectedLocation;
    if (location == null) return;

    await manager.add(
      Symbol(
        'selected-location',
        SymbolOptions(
          geometry: location,
          iconImage: _customIconsLoaded ? _selectedLocationIconId : 'marker',
          iconSize: 0.6,
          iconAnchor: 'center',
        ),
      ),
    );
  }

  Future<void> _syncDestinationMarker() async {
    final manager = _destinationCircleManager;
    if (manager == null || !manager.isInitialized) return;
    if (manager.controller.isDisposed) return;

    final request = ++_destinationSyncRequest;

    try {
      await manager.clear();
      if (!mounted ||
          request != _destinationSyncRequest ||
          manager.controller.isDisposed) {
        return;
      }

      final destination = _selectedDestination;
      if (destination == null) return;

      await manager.addAll([
        Circle(
          'destination-halo',
          CircleOptions(
            geometry: destination,
            circleRadius: 16,
            circleColor: _destinationColorHex,
            circleOpacity: 0.18,
            circleStrokeWidth: 0,
          ),
        ),
        Circle(
          'destination-marker',
          CircleOptions(
            geometry: destination,
            circleRadius: 9,
            circleColor: _destinationColorHex,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        ),
        Circle(
          'destination-center',
          CircleOptions(
            geometry: destination,
            circleRadius: 3,
            circleColor: '#FFFFFF',
          ),
        ),
      ]);
    } catch (error) {
      debugPrint('Varış işareti güncellenemedi: $error');
    }
  }

  Future<void> _syncRouteLine() async {
    final manager = _routeLineManager;
    if (manager == null || !manager.isInitialized) return;
    if (manager.controller.isDisposed) return;

    final state = ref.read(routeControllerProvider);
    if (state is RouteLoading) return;

    final request = ++_routeSyncRequest;

    try {
      await manager.clear();
      if (!mounted ||
          request != _routeSyncRequest ||
          manager.controller.isDisposed) {
        return;
      }

      if (state is! RouteLoaded) return;

      final points = state.route.pathPoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList(growable: false);
      if (points.length < 2) return;

      await manager.add(
        Line(
          _routeLineId,
          LineOptions(
            geometry: points,
            lineColor: '#2196F3',
            lineWidth: 5.0,
            lineJoin: 'round',
          ),
        ),
      );
    } catch (error) {
      debugPrint('Rota çizgisi güncellenemedi: $error');
    }
  }

  void _handleMapClick(LatLng coordinates) {
    // FAB veya harita üzerindeki Flutter kontrollerine yapılan dokunuşların
    // MapLibre tarafında ikinci kez işlenmesini engelle.
    if (_shouldIgnoreMapClick) return;

    // Harita dokunuşları yalnızca hedef seçimi modunda işlenir.
    if (!_isSelectingDestination) return;

    _handleDestinationSelected(coordinates);
  }

  bool get _shouldIgnoreMapClick {
    final lastInteraction = _lastMapControlInteractionAt;
    if (lastInteraction == null) return false;

    return DateTime.now().difference(lastInteraction) <
        const Duration(milliseconds: 500);
  }

  Widget _guardMapControl(Widget child) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _markMapControlInteraction(),
      onPointerUp: (_) => _markMapControlInteraction(),
      onPointerCancel: (_) => _markMapControlInteraction(),
      child: child,
    );
  }

  void _markMapControlInteraction() {
    _lastMapControlInteractionAt = DateTime.now();
  }

  void _handleSearchLocationSelected(double latitude, double longitude) {
    final controller = _mapController;
    if (controller == null || controller.isDisposed) return;

    unawaited(
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(latitude, longitude), 16.0),
      ),
    );
  }

  void _handleDestinationSelected(LatLng destination) {
    setState(() {
      _isSelectingDestination = false;
      _selectedDestination = destination;
    });
    unawaited(_syncDestinationMarker());
    unawaited(_openNavigationSheet(initialDestination: destination));
  }

  Future<void> _openCreateReportSheet() async {
    if (_isSelectingDestination) {
      setState(() {
        _isSelectingDestination = false;
        _selectedDestination = null;
        _navigationStart = null;
      });
      unawaited(_syncDestinationMarker());
    }

    final location = _selectedLocation ?? _bartinCenter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (_) => CreateReportSheet(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
    );
  }

  Future<LatLng> _resolveNavigationStart() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return _bartinCenter;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _bartinCenter;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 8),
      );

      // Sheet'te gösterilen 5 ondalıklı değerle aynı koordinatı kullan.
      final location = LatLng(
        double.parse(position.latitude.toStringAsFixed(5)),
        double.parse(position.longitude.toStringAsFixed(5)),
      );
      _currentGpsLocation = location;
      return location;
    } catch (error) {
      debugPrint('Mevcut konum alınamadı, Bartın merkezi kullanılacak: $error');
      return _bartinCenter;
    }
  }

  bool _isCurrentGpsLocation(LatLng location) {
    final current = _currentGpsLocation;
    if (current == null) return false;

    return (location.latitude - current.latitude).abs() < 0.00002 &&
        (location.longitude - current.longitude).abs() < 0.00002;
  }

  bool _isBartinCenter(LatLng location) {
    return (location.latitude - _bartinCenter.latitude).abs() < 0.00002 &&
        (location.longitude - _bartinCenter.longitude).abs() < 0.00002;
  }

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  Future<void> _openNavigationSheet({LatLng? initialDestination}) async {
    if (!mounted || _isResolvingNavigationStart) return;

    if (_isSelectingDestination) {
      setState(() => _isSelectingDestination = false);
    }

    LatLng start;
    if (initialDestination != null && _navigationStart != null) {
      // Haritadan hedef seçilirken ilk açılıştaki başlangıç korunur.
      start = _navigationStart!;
    } else {
      setState(() => _isResolvingNavigationStart = true);
      try {
        start = await _resolveNavigationStart();
      } finally {
        if (mounted) {
          setState(() => _isResolvingNavigationStart = false);
        }
      }

      if (!mounted) return;
      _navigationStart = start;
    }

    if (initialDestination == null) {
      if (_selectedDestination != null) {
        setState(() => _selectedDestination = null);
        unawaited(_syncDestinationMarker());
      }
    } else if (_selectedDestination != initialDestination) {
      setState(() => _selectedDestination = initialDestination);
      unawaited(_syncDestinationMarker());
    }

    _isNavigationSheetOpen = true;

    NavigationSheetAction? action;
    try {
      action = await showModalBottomSheet<NavigationSheetAction>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        builder:
            (_) => NavigationSheet(
              startLat: start.latitude,
              startLng: start.longitude,
              startIsCurrentLocation: _isCurrentGpsLocation(start),
              initialDestinationLat: initialDestination?.latitude,
              initialDestinationLng: initialDestination?.longitude,
            ),
      );
    } finally {
      _isNavigationSheetOpen = false;
    }

    if (!mounted) return;

    if (action == NavigationSheetAction.selectFromMap) {
      setState(() {
        _isSelectingDestination = true;
        _selectedDestination = null;
      });
      unawaited(_syncDestinationMarker());
      return;
    }

    _navigationStart = null;
  }

  void _clearRoute() {
    setState(() {
      _navigationStart = null;
      _selectedDestination = null;
      _isSelectingDestination = false;
    });
    unawaited(_syncDestinationMarker());
    ref.read(routeControllerProvider.notifier).clearRoute();
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Onay diyaloğu
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Çıkış Yap'),
            content: const Text(
              'Hesabınızdan çıkmak istediğinize emin misiniz?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Çıkış Yap'),
              ),
            ],
          ),
    );

    if (shouldLogout == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  Widget _buildMapHint(BuildContext context) {
    final hintIcon =
        _isSelectingDestination ? Icons.flag_outlined : Icons.info_outline;

    final hintText =
        _isSelectingDestination
            ? 'Lütfen haritada hedef noktayı seçin'
            : 'Engel bildirmek için "Engel Bildir" düğmesini kullanın';

    return Positioned(
      top: 76,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  hintIcon,
                  size: 20,
                  color:
                      _isSelectingDestination
                          ? _destinationColor
                          : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hintText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight:
                          _isSelectingDestination ? FontWeight.w600 : null,
                      color: _isSelectingDestination ? _destinationColor : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteOverlay(BuildContext context, RouteLoaded routeState) {
    final route = routeState.route;
    final distanceInKm = route.distanceInMeters / 1000;
    final score = route.accessibilityScore;
    final scoreColor =
        score >= 80
            ? Colors.green[700]
            : score >= 50
            ? Colors.orange[700]
            : Colors.red[700];
    final routeStart = LatLng(route.startLat, route.startLng);
    final startLabel =
        _isCurrentGpsLocation(routeStart)
            ? 'Mevcut Konum'
            : _isBartinCenter(routeStart)
            ? 'Bartın Merkezi'
            : _formatCoordinates(route.startLat, route.startLng);
    final endLabel = _formatCoordinates(route.endLat, route.endLng);

    return Positioned(
      top: 124,
      left: 12,
      right: 12,
      child: _guardMapControl(
        Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.97),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _routeColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.route, color: _routeColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Başlangıç: $startLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bitiş: $endLabel',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 16,
                          color: _routeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Mesafe: ${distanceInKm.toStringAsFixed(2)} km',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.accessible, size: 16, color: scoreColor),
                        const SizedBox(width: 4),
                        Text(
                          'Erişilebilirlik Skoru: '
                          '${score.toStringAsFixed(0)}/100',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(
                            color: scoreColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _clearRoute,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.clear, size: 18),
                    label: const Text('Rotayı Temizle'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRouteLoadingOverlay(BuildContext context) {
    return Positioned(
      top: 124,
      left: 12,
      right: 12,
      child: IgnorePointer(
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(14),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _routeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Rota hesaplanıyor...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final routeState = ref.watch(routeControllerProvider);

    // Yeni bildirimler yüklendiğinde harita işaretlerini güncelle.
    ref.listen<ReportState>(reportControllerProvider, (previous, next) {
      if (next is ReportLoaded) {
        unawaited(_syncReportMarkers());
        if (_showHeatmap) {
          _scheduleHeatmapSync();
        }
      }
    });

    // Rota değiştiğinde çizgiyi güncelle ve hata varsa kullanıcıya bildir.
    ref.listen<RouteState>(routeControllerProvider, (previous, next) {
      if (next is RouteError && !_isNavigationSheetOpen) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.message),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        });
      }

      unawaited(_syncRouteLine());
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Erişilebilirlik Haritası'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          // Kullanıcı avatarı
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: PopupMenuButton<String>(
                offset: const Offset(0, 50),
                icon: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onSelected: (value) {
                  if (value == 'logout') {
                    _handleLogout(context);
                  } else if (value == 'profile') {
                    context.go('/profile');
                  }
                },
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        enabled: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    user.isAdmin
                                        ? Colors.red[100]
                                        : user.isVolunteer
                                        ? Colors.orange[100]
                                        : Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user.role.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color:
                                      user.isAdmin
                                          ? Colors.red[900]
                                          : user.isVolunteer
                                          ? Colors.orange[900]
                                          : Colors.blue[900],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'profile',
                        child: Row(
                          children: [
                            Icon(Icons.person_outline),
                            SizedBox(width: 12),
                            Text('Profilim'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 12),
                            Text(
                              'Çıkış Yap',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          MapLibreMap(
            styleString: _mapStyleUrl,
            initialCameraPosition: const CameraPosition(
              target: _bartinCenter,
              zoom: 16.0,
              tilt: 60.0,
            ),
            trackCameraPosition: true,
            // FAB'ın attribution düğmesini kapatmaması için sol alta al.
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: (_, coordinates) => _handleMapClick(coordinates),
          ),
          _buildMapHint(context),
          if (routeState is RouteLoaded)
            _buildRouteOverlay(context, routeState)
          else if (routeState is RouteLoading)
            _buildRouteLoadingOverlay(context),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: SafeArea(
              // Gövde AppBar'ın altında başladığı için üst inset'i tekrar eklemiyoruz.
              top: false,
              bottom: false,
              child: _guardMapControl(
                MapSearchBar(onLocationSelected: _handleSearchLocationSelected),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _guardMapControl(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'navigation-fab',
              tooltip: 'Navigasyon',
              onPressed:
                  _isResolvingNavigationStart ? null : _openNavigationSheet,
              backgroundColor: _routeColor,
              foregroundColor: Colors.white,
              child:
                  _isResolvingNavigationStart
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.directions),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'report-fab',
              onPressed: _openCreateReportSheet,
              backgroundColor: const Color(0xFF26A69A),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Engel Bildir'),
            ),
          ],
        ),
      ),
    );
  }
}
