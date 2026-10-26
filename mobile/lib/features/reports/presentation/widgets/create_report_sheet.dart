// ============================================================
// create_report_sheet.dart
// Engel bildirimi oluşturma modal bottom sheet'i
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/report_provider.dart';
import '../report_categories.dart';

class CreateReportSheet extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;
  final bool isUsingFallbackLocation;

  const CreateReportSheet({
    super.key,
    required this.latitude,
    required this.longitude,
    this.isUsingFallbackLocation = false,
  });

  @override
  ConsumerState<CreateReportSheet> createState() => _CreateReportSheetState();
}

class _CreateReportSheetState extends ConsumerState<CreateReportSheet> {
  static const Color _brandColor = Color(0xFF1565C0);

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _previewBytes;
  bool _isPickingImage = false;
  bool _isSubmitting = false;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_syncSelectedCategory);
  }

  @override
  void dispose() {
    _titleController.removeListener(_syncSelectedCategory);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncSelectedCategory() {
    final title = _titleController.text.trim();

    String? matchingLabel;
    for (final category in ReportCategory.values) {
      if (category.displayLabel == title || category.label == title) {
        matchingLabel = category.displayLabel;
        break;
      }
    }

    if (!mounted || matchingLabel == _selectedCategory) return;
    setState(() => _selectedCategory = matchingLabel);
  }

  void _selectCategory(ReportCategory category) {
    _titleController.value = TextEditingValue(
      text: category.displayLabel,
      selection: TextSelection.collapsed(offset: category.displayLabel.length),
    );

    if (_selectedCategory != category.displayLabel) {
      setState(() => _selectedCategory = category.displayLabel);
    }
  }

  Future<void> _handlePickPhoto() async {
    setState(() => _isPickingImage = true);

    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      setState(() {
        _selectedImage = picked;
        _previewBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fotoğraf seçilemedi: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  void _removePhoto() {
    setState(() {
      _selectedImage = null;
      _previewBytes = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(reportControllerProvider.notifier)
        .submitReport(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          lat: widget.latitude,
          lng: widget.longitude,
          photo: _selectedImage,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      ref.invalidate(getRecentReportsProvider);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Bildiriminiz başarıyla gönderildi'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final state = ref.read(reportControllerProvider);
    final message =
        state is ReportError
            ? state.message
            : 'Bildirim gönderilemedi, lütfen tekrar deneyin';

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1A2B4C),
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildLocationBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _brandColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _brandColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _brandColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: _brandColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Konum',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.latitude.toStringAsFixed(5)}, '
                  '${widget.longitude.toStringAsFixed(5)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.isUsingFallbackLocation) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 15,
                        color: Color(0xFFE65100),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'GPS konumu alınamadı, harita merkezi kullanıldı.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFFE65100),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context) {
    final options = ReportCategory.values
        .where((category) => category != ReportCategory.other)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Engel Türü'),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _buildCategoryCard(context, options[i])),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _buildOtherCard(context, ReportCategory.other),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, ReportCategory category) {
    final isSelected = _selectedCategory == category.displayLabel;
    final color = category.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectCategory(category),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: isSelected ? 0.45 : 0.28),
                        blurRadius: isSelected ? 10 : 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(category.icon, size: 28, color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                category.displayLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF1A2B4C),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherCard(BuildContext context, ReportCategory category) {
    final isSelected = _selectedCategory == category.displayLabel;
    final color = category.color;

    return Material(
      color: isSelected ? color.withValues(alpha: 0.10) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? color : const Color(0xFFE0E4EA),
          width: isSelected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _selectCategory(category),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(category.icon, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Text(
                category.displayLabel,
                style: TextStyle(
                  color: isSelected ? color : const Color(0xFF1A2B4C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Fotoğraf Ekle'),
        const SizedBox(height: 10),
        if (_previewBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Image.memory(
                  _previewBytes!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  semanticLabel: 'Seçilen fotoğraf önizlemesi',
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Fotoğrafı kaldır',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: _removePhoto,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          _buildPhotoPlaceholder(context),
        if (_previewBytes != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  _isSubmitting || _isPickingImage ? null : _handlePickPhoto,
              icon:
                  _isPickingImage
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                      : const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(
                _selectedImage == null ? 'Fotoğraf Seç' : 'Fotoğrafı Değiştir',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        if (_isPickingImage && _previewBytes == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _buildLoadingRow(theme),
          ),
      ],
    );
  }

  Widget _buildLoadingRow(ThemeData theme) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text(
          'Fotoğraf yükleniyor...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPlaceholder(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: _brandColor.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _handlePickPhoto,
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: _brandColor.withValues(alpha: 0.45),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _brandColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: _brandColor,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Fotoğraf ekle',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _brandColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Engelin fotoğrafını yükleyin (isteğe bağlı)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Engel Bildir',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2B4C),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hangi konuda bildirimde bulunmak istiyorsunuz?',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _buildLocationBanner(context),
                const SizedBox(height: 20),
                _buildCategorySection(context),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  maxLength: 150,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Başlık',
                    hintText: 'Örn. Kaldırımda çukur var',
                    prefixIcon: const Icon(Icons.title),
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE0E4EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _brandColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Başlık boş bırakılamaz';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 500,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Engeli kısaca açıklayın (isteğe bağlı)',
                    prefixIcon: const Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: const Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE0E4EA)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _brandColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPhotoSection(context),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _brandColor.withValues(
                      alpha: 0.45,
                    ),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Text('Gönder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Yarım daire köşeli kesikli (dashed) kenarlık çizer.
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);

    const dashWidth = 6.0;
    const dashGap = 4.0;

    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = (start + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
