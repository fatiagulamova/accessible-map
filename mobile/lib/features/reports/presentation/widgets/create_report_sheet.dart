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
      if (category.label == title) {
        matchingLabel = category.label;
        break;
      }
    }

    if (!mounted || matchingLabel == _selectedCategory) return;
    setState(() => _selectedCategory = matchingLabel);
  }

  void _selectCategory(ReportCategory category) {
    _titleController.value = TextEditingValue(
      text: category.label,
      selection: TextSelection.collapsed(offset: category.label.length),
    );

    if (_selectedCategory != category.label) {
      setState(() => _selectedCategory = category.label);
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

  Widget _buildCategorySection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < ReportCategory.values.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _buildCategoryChip(context, ReportCategory.values[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context, ReportCategory category) {
    final isSelected = _selectedCategory == category.label;
    final foregroundColor = isSelected ? Colors.white : category.color;

    return ChoiceChip(
      selected: isSelected,
      showCheckmark: false,
      onSelected: (_) => _selectCategory(category),
      avatar: Icon(category.icon, size: 18, color: foregroundColor),
      label: Text(
        category.label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      labelPadding: const EdgeInsets.only(left: 2, right: 4),
      backgroundColor: category.color.withValues(alpha: 0.10),
      selectedColor: category.color,
      side: BorderSide(
        color: category.color.withValues(alpha: isSelected ? 1 : 0.35),
      ),
      shape: const StadiumBorder(),
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Engel Bildir',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  initialValue:
                      '${widget.latitude.toStringAsFixed(5)}, '
                      '${widget.longitude.toStringAsFixed(5)}',
                  readOnly: true,
                  showCursor: false,
                  decoration: const InputDecoration(
                    labelText: 'Konum',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    helperText: 'Konum otomatik olarak alındı',
                  ),
                ),
                if (widget.isUsingFallbackLocation) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: theme.colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'GPS konumu alınamadı, harita merkezi kullanılıyor.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _buildCategorySection(context),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  maxLength: 150,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Başlık',
                    hintText: 'Örn. Kaldırımda çukur var',
                    prefixIcon: Icon(Icons.title),
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
                  decoration: const InputDecoration(
                    labelText: 'Açıklama',
                    hintText: 'Engeli kısaca açıklayın (isteğe bağlı)',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                if (_previewBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: _removePhoto,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                OutlinedButton.icon(
                  onPressed:
                      _isSubmitting || _isPickingImage
                          ? null
                          : _handlePickPhoto,
                  icon:
                      _isPickingImage
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                          : const Icon(Icons.photo_library_outlined),
                  label: Text(
                    _selectedImage == null
                        ? 'Fotoğraf Seç'
                        : 'Fotoğrafı Değiştir',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  icon:
                      _isSubmitting
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.send),
                  label: Text(_isSubmitting ? 'Gönderiliyor...' : 'Gönder'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
