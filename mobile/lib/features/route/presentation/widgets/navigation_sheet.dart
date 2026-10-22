// ============================================================
// navigation_sheet.dart
// Navigasyon hedefi seçimi ve rota hesaplama modal bottom sheet'i
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  static const String _bartinUniversityCoordinates = '41.6362, 32.3410';
  static const Color _brandColor = Color(0xFF1565C0);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _startController;
  late final TextEditingController _destinationController;

  bool _isCalculating = false;
  String? _calculationError;

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: _formatCoordinates(widget.startLat, widget.startLng),
    );

    final initialLat = widget.initialDestinationLat;
    final initialLng = widget.initialDestinationLng;
    _destinationController = TextEditingController(
      text:
          initialLat != null && initialLng != null
              ? _formatCoordinates(initialLat, initialLng)
              : '',
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  String _formatCoordinates(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
  }

  void _useBartinUniversityDestination() {
    setState(() {
      _destinationController.text = _bartinUniversityCoordinates;
      _destinationController.selection = TextSelection.collapsed(
        offset: _destinationController.text.length,
      );
      _calculationError = null;
    });
  }

  void _selectFromMap() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(NavigationSheetAction.selectFromMap);
  }

  Future<void> _calculateRoute() async {
    if (_isCalculating || !_formKey.currentState!.validate()) return;

    final startCoordinates = _parseCoordinates(_startController.text)!;
    final destinationCoordinates =
        _parseCoordinates(_destinationController.text)!;
    FocusScope.of(context).unfocus();

    setState(() {
      _isCalculating = true;
      _calculationError = null;
    });

    await ref
        .read(routeControllerProvider.notifier)
        .calculateRoute(
          startLat: startCoordinates[0],
          startLng: startCoordinates[1],
          endLat: destinationCoordinates[0],
          endLng: destinationCoordinates[1],
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

  /// "Enlem, boylam" biçimindeki metni iki ondalık sayıya çevirir.
  List<double>? _parseCoordinates(String input) {
    final tokens =
        input
            .trim()
            .split(RegExp(r'[,;\s]+'))
            .where((token) => token.isNotEmpty)
            .toList();

    if (tokens.length != 2) return null;

    final latitude = double.tryParse(tokens[0]);
    final longitude = double.tryParse(tokens[1]);
    if (latitude == null || longitude == null) return null;

    return [latitude, longitude];
  }

  String? _validateCoordinates(
    String? value, {
    required String emptyMessage,
    required String invalidMessage,
  }) {
    if (value == null || value.trim().isEmpty) {
      return emptyMessage;
    }

    final coordinates = _parseCoordinates(value);
    if (coordinates == null) {
      return invalidMessage;
    }

    final latitude = coordinates[0];
    final longitude = coordinates[1];

    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      return 'Enlem -90 ile 90 arasında olmalıdır';
    }

    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      return 'Boylam -180 ile 180 arasında olmalıdır';
    }

    return null;
  }

  String? _validateStart(String? value) {
    return _validateCoordinates(
      value,
      emptyMessage: 'Başlangıç noktası boş bırakılamaz',
      invalidMessage:
          'Başlangıç koordinatlarını "enlem, boylam" biçiminde girin',
    );
  }

  String? _validateDestination(String? value) {
    return _validateCoordinates(
      value,
      emptyMessage: 'Bitiş noktası boş bırakılamaz',
      invalidMessage: 'Koordinatları "enlem, boylam" biçiminde girin',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
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
                            'Başlangıç ve bitiş noktalarını belirleyin.',
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Başlangıç',
                    hintText: 'Mevcut Konum',
                    helperText:
                        widget.startIsCurrentLocation
                            ? 'Mevcut GPS konumunuz otomatik dolduruldu'
                            : 'GPS kullanılamadı; Bartın merkezi kullanıldı',
                    prefixIcon: const Icon(
                      Icons.my_location,
                      color: _brandColor,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Başlangıç alanını temizle',
                      onPressed: () => _startController.clear(),
                      icon: const Icon(
                        Icons.clear,
                        size: 20,
                        color: _brandColor,
                      ),
                    ),
                  ),
                  validator: _validateStart,
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).nextFocus();
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _destinationController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Bitiş',
                          hintText: '41.6362, 32.3410',
                          helperText: 'Enlem ve boylamı virgülle ayırın',
                          prefixIcon: const Icon(
                            Icons.flag_outlined,
                            color: _brandColor,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Bitiş alanını temizle',
                            onPressed: () => _destinationController.clear(),
                            icon: const Icon(
                              Icons.clear,
                              size: 20,
                              color: _brandColor,
                            ),
                          ),
                        ),
                        validator: _validateDestination,
                        onFieldSubmitted: (_) {
                          if (!_isCalculating) {
                            _calculateRoute();
                          }
                        },
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed:
                        _isCalculating ? null : _useBartinUniversityDestination,
                    style: TextButton.styleFrom(foregroundColor: _brandColor),
                    icon: const Icon(Icons.school_outlined, size: 18),
                    label: const Text('Bartın Üniversitesi'),
                  ),
                ),
                if (_calculationError != null) ...[
                  const SizedBox(height: 4),
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
                  onPressed: _isCalculating ? null : _calculateRoute,
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
}
