// ============================================================
// navigation_sheet.dart
// Navigasyon hedefi seçimi ve rota hesaplama modal bottom sheet'i
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers/route_provider.dart';

/// NavigationSheet kapandıktan sonra harita sayfasının yapacağı eylem.
enum NavigationSheetAction { selectFromMap }

class NavigationSheet extends ConsumerStatefulWidget {
  final double startLat;
  final double startLng;
  final bool startIsCurrentLocation;

  /// Haritadan seçilen ve yeniden açılan sheet'te "Bitiş" alanına
  /// yazılacak isteğe bağlı başlangıç değerleri.
  final double? initialDestinationLat;
  final double? initialDestinationLng;

  const NavigationSheet({
    super.key,
    required this.startLat,
    required this.startLng,
    this.startIsCurrentLocation = true,
    this.initialDestinationLat,
    this.initialDestinationLng,
  });

  @override
  ConsumerState<NavigationSheet> createState() => _NavigationSheetState();
}

class _NavigationSheetState extends ConsumerState<NavigationSheet> {
  static const Color _brandColor = Color(0xFF1565C0);
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  static const int _maxSearchResults = 5;

  final _formKey = GlobalKey<FormState>();
  final _httpClient = http.Client();
  final _destinationFocusNode = FocusNode();

  late final TextEditingController _startController;
  late final TextEditingController _destinationController;

  Timer? _debounce;
  int _searchRequestId = 0;
  List<_PlaceResult> _searchResults = const <_PlaceResult>[];
  bool _isSearching = false;
  String? _searchMessage;

  double? _endLat;
  double? _endLng;

  bool _isCalculating = false;
  String? _calculationError;

  bool get _hasDestination => _endLat != null && _endLng != null;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: _formatCoordinates(widget.startLat, widget.startLng),
    );

    final initialLat = widget.initialDestinationLat;
    final initialLng = widget.initialDestinationLng;
    if (initialLat != null && initialLng != null) {
      _endLat = initialLat;
      _endLng = initialLng;
    }

    _destinationController = TextEditingController(
      text:
          initialLat != null && initialLng != null
              ? _formatCoordinates(initialLat, initialLng)
              : '',
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _destinationFocusNode.dispose();
    _httpClient.close();
    _startController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  void _onDestinationChanged(String value) {
    _debounce?.cancel();
    _searchRequestId++;

    final query = value.trim();
    setState(() {
      _searchResults = const <_PlaceResult>[];
      _searchMessage = null;
      _isSearching = false;
      _endLat = null;
      _endLng = null;
      _calculationError = null;
    });

    if (query.isEmpty) return;

    _debounce = Timer(_debounceDuration, () => _searchDestination(query));
  }

  Future<void> _searchDestination(String query) async {
    if (!mounted) return;

    final requestId = ++_searchRequestId;
    setState(() {
      _isSearching = true;
      _searchMessage = null;
      _searchResults = const <_PlaceResult>[];
    });

    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '$_maxSearchResults',
      });
      final response = await _httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (!mounted || requestId != _searchRequestId) return;

      if (response.statusCode != 200) {
        throw Exception('Photon isteği başarısız: ${response.statusCode}');
      }

      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final features =
          payload is Map<String, dynamic> ? payload['features'] : null;
      final results = <_PlaceResult>[];

      if (features is List) {
        for (final feature in features.take(_maxSearchResults)) {
          final result = _PlaceResult.fromFeature(feature);
          if (result != null) results.add(result);
        }
      }

      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _isSearching = false;
        _searchResults = results;
        _searchMessage = results.isEmpty ? 'Sonuç bulunamadı' : null;
      });
    } catch (error) {
      debugPrint('Photon hedef araması başarısız: $error');
      if (!mounted || requestId != _searchRequestId) return;

      setState(() {
        _isSearching = false;
        _searchResults = const <_PlaceResult>[];
        _searchMessage = 'Arama sırasında bir hata oluştu';
      });
    }
  }

  void _submitDestinationSearch(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty || _hasDestination) return;

    unawaited(_searchDestination(query));
  }

  void _selectDestination(_PlaceResult result) {
    _debounce?.cancel();
    _searchRequestId++;
    _destinationController.text = result.name;
    _destinationController.selection = TextSelection.collapsed(
      offset: result.name.length,
    );
    _destinationFocusNode.unfocus();

    setState(() {
      _endLat = result.latitude;
      _endLng = result.longitude;
      _searchResults = const <_PlaceResult>[];
      _searchMessage = null;
      _isSearching = false;
      _calculationError = null;
    });
  }

  void _clearDestination() {
    _debounce?.cancel();
    _searchRequestId++;
    _destinationController.clear();
    _destinationFocusNode.requestFocus();

    setState(() {
      _endLat = null;
      _endLng = null;
      _searchResults = const <_PlaceResult>[];
      _searchMessage = null;
      _isSearching = false;
      _calculationError = null;
    });
  }

  void _selectFromMap() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(NavigationSheetAction.selectFromMap);
  }

  Future<void> _calculateRoute() async {
    if (_isCalculating) return;

    final endLat = _endLat;
    final endLng = _endLng;
    if (endLat == null || endLng == null) {
      setState(() {
        _calculationError =
            'Lütfen aramadan veya haritadan bir bitiş noktası seçin';
      });
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isCalculating = true;
      _calculationError = null;
    });

    await ref
        .read(routeControllerProvider.notifier)
        .calculateRoute(
          startLat: widget.startLat,
          startLng: widget.startLng,
          endLat: endLat,
          endLng: endLng,
        );

    if (!mounted) return;

    final state = ref.read(routeControllerProvider);
    if (state is RouteLoaded) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isCalculating = false;
      _calculationError =
          state is RouteError
              ? state.message
              : 'Rota hesaplanamadı, lütfen tekrar deneyin';
    });
  }

  String? _validateDestination(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bitiş noktası boş bırakılamaz';
    }

    if (!_hasDestination) {
      return 'Lütfen aramadan bir bitiş noktası seçin';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final hasDestinationText = _destinationController.text.trim().isNotEmpty;
    final showSearchResults =
        _searchResults.isNotEmpty || _searchMessage != null;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _brandColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.directions,
                        color: _brandColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Navigasyon',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bitiş noktasını arayın veya haritadan seçin.',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Kapat',
                      icon: const Icon(Icons.close, color: _brandColor),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _startController,
                  readOnly: true,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  decoration: InputDecoration(
                    labelText: 'Başlangıç',
                    hintText: 'Mevcut Konum',
                    helperText:
                        widget.startIsCurrentLocation
                            ? 'Mevcut Konum · GPS koordinatları otomatik dolduruldu'
                            : 'Mevcut Konum · GPS kullanılamadı; Bartın merkezi kullanıldı',
                    prefixIcon: const Icon(
                      Icons.my_location,
                      color: _brandColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _destinationController,
                        focusNode: _destinationFocusNode,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.search,
                        textCapitalization: TextCapitalization.words,
                        onChanged: _onDestinationChanged,
                        onFieldSubmitted: _submitDestinationSearch,
                        decoration: InputDecoration(
                          labelText: 'Bitiş',
                          hintText: 'Yer, sokak veya kurum arayın',
                          helperText:
                              _hasDestination
                                  ? 'Seçilen konum kullanılacak'
                                  : hasDestinationText
                                  ? 'Aramadan bir sonuç seçin'
                                  : 'Yer arayın veya haritadan seçin',
                          prefixIcon: const Icon(
                            Icons.flag_outlined,
                            color: _brandColor,
                          ),
                          suffixIcon:
                              hasDestinationText
                                  ? IconButton(
                                    tooltip: 'Bitiş alanını temizle',
                                    onPressed:
                                        _isCalculating
                                            ? null
                                            : _clearDestination,
                                    icon: const Icon(
                                      Icons.clear,
                                      size: 20,
                                      color: _brandColor,
                                    ),
                                  )
                                  : null,
                        ),
                        validator: _validateDestination,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _isCalculating ? null : _selectFromMap,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brandColor,
                          side: const BorderSide(color: _brandColor),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text(
                          'Haritadan Seç',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isSearching) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: _brandColor,
                  ),
                ],
                if (showSearchResults) ...[
                  const SizedBox(height: 8),
                  _buildSearchResults(context),
                ],
                if (_calculationError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 20,
                          color: Colors.red[700],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _calculationError!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      _isCalculating || !_hasDestination
                          ? null
                          : _calculateRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                  ),
                  icon:
                      _isCalculating
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.directions),
                  label: Text(
                    _isCalculating ? 'Rota hesaplanıyor...' : 'Rotayı Hesapla',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child:
            _searchResults.isEmpty
                ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _searchMessage ?? 'Sonuç bulunamadı',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
                : ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const ClampingScrollPhysics(),
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: _brandColor.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.place_outlined,
                          size: 20,
                          color: _brandColor,
                        ),
                      ),
                      title: Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle:
                          result.subtitle.isEmpty
                              ? null
                              : Text(
                                result.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      trailing: const Icon(
                        Icons.north_west,
                        size: 18,
                        color: _brandColor,
                      ),
                      onTap: () => _selectDestination(result),
                    );
                  },
                ),
      ),
    );
  }
}

class _PlaceResult {
  final String name;
  final String subtitle;
  final double latitude;
  final double longitude;

  const _PlaceResult({
    required this.name,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  static _PlaceResult? fromFeature(dynamic feature) {
    if (feature is! Map<String, dynamic>) return null;

    final geometry = feature['geometry'];
    if (geometry is! Map<String, dynamic>) return null;

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;

    final rawLongitude = coordinates[0];
    final rawLatitude = coordinates[1];
    if (rawLongitude is! num || rawLatitude is! num) return null;

    final latitude = rawLatitude.toDouble();
    final longitude = rawLongitude.toDouble();
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final properties = feature['properties'];
    if (properties is! Map<String, dynamic>) return null;

    final street = _textValue(properties['street']);
    final district = _textValue(properties['district']);
    final city = _textValue(properties['city']);
    final state = _textValue(properties['state']);
    final country = _textValue(properties['country']);
    final name =
        _textValue(properties['name']) ??
        street ??
        city ??
        district ??
        state ??
        country;

    if (name == null) return null;

    final subtitleParts = <String>[];
    for (final part in [street, district, city, state, country]) {
      if (part != null && part != name && !subtitleParts.contains(part)) {
        subtitleParts.add(part);
      }
    }

    return _PlaceResult(
      name: name,
      subtitle: subtitleParts.join(', '),
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String? _textValue(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }
}
