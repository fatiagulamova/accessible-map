// ============================================================
// map_search_bar.dart
// Haritada yer aramak için yüzen arama çubuğu (Photon API)
// ============================================================

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MapSearchBar extends StatefulWidget {
  final void Function(double lat, double lng) onLocationSelected;

  const MapSearchBar({super.key, required this.onLocationSelected});

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  static const Color _brandColor = Color(0xFF1565C0);
  static const Duration _debounceDuration = Duration(milliseconds: 500);

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final http.Client _httpClient = http.Client();

  Timer? _debounce;
  List<_PlaceResult> _results = const <_PlaceResult>[];
  bool _isLoading = false;
  String? _message;
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _httpClient.close();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _requestId++;

    final query = value.trim();
    setState(() {
      _results = const <_PlaceResult>[];
      _message = null;
      _isLoading = false;
    });

    if (query.isEmpty) return;

    _debounce = Timer(_debounceDuration, () => _search(query));
  }

  Future<void> _search(String query) async {
    final requestId = ++_requestId;

    setState(() {
      _isLoading = true;
      _message = null;
      _results = const <_PlaceResult>[];
    });

    try {
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '5',
      });
      final response = await _httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (!mounted || requestId != _requestId) return;

      if (response.statusCode != 200) {
        throw Exception('Photon isteği başarısız: ${response.statusCode}');
      }

      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final features =
          payload is Map<String, dynamic> ? payload['features'] : null;
      final results = <_PlaceResult>[];

      if (features is List) {
        for (final feature in features.take(5)) {
          final result = _PlaceResult.fromFeature(feature);
          if (result != null) results.add(result);
        }
      }

      if (!mounted || requestId != _requestId) return;

      setState(() {
        _isLoading = false;
        _results = results;
        _message = results.isEmpty ? 'Sonuç bulunamadı' : null;
      });
    } catch (error) {
      debugPrint('Photon araması başarısız: $error');
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _isLoading = false;
        _results = const <_PlaceResult>[];
        _message = 'Arama sırasında bir hata oluştu';
      });
    }
  }

  void _submit(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) return;

    unawaited(_search(query));
  }

  void _clearSearch() {
    _debounce?.cancel();
    _requestId++;
    _controller.clear();

    setState(() {
      _results = const <_PlaceResult>[];
      _message = null;
      _isLoading = false;
    });

    _focusNode.requestFocus();
  }

  void _selectResult(_PlaceResult result) {
    _debounce?.cancel();
    _requestId++;
    _controller.clear();
    _focusNode.unfocus();

    setState(() {
      _results = const <_PlaceResult>[];
      _message = null;
      _isLoading = false;
    });

    widget.onLocationSelected(result.latitude, result.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final showResults = _results.isNotEmpty || _message != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 6,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onQueryChanged,
                onSubmitted: _submit,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Yer, sokak veya mahalle ara',
                  prefixIcon: const Icon(Icons.search, color: _brandColor),
                  suffixIcon:
                      hasText
                          ? IconButton(
                            tooltip: 'Aramayı temizle',
                            onPressed: _clearSearch,
                            icon: const Icon(Icons.clear, color: _brandColor),
                          )
                          : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_isLoading)
                const LinearProgressIndicator(minHeight: 2, color: _brandColor),
            ],
          ),
        ),
        if (showResults) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            elevation: 6,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child:
                  _results.isEmpty
                      ? _buildMessage(context)
                      : ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final result = _results[index];
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: _brandColor.withValues(
                                alpha: 0.10,
                              ),
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
                            onTap: () => _selectResult(result),
                          );
                        },
                      ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMessage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _message ?? 'Sonuç bulunamadı',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
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
