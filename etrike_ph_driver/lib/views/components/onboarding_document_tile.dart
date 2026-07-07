import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_decorations.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/onboarding_upload_utils.dart';
import '../../models/onboarding_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../core/driver_route_guard.dart';

/// Upload tile for onboarding documents — camera, gallery, or PDF/file.
class OnboardingDocumentTile extends ConsumerStatefulWidget {
  const OnboardingDocumentTile({
    super.key,
    required this.docType,
    required this.existing,
    required this.onUploaded,
  });

  final DocumentType docType;
  final DriverDocumentRow? existing;
  final VoidCallback onUploaded;

  @override
  ConsumerState<OnboardingDocumentTile> createState() =>
      _OnboardingDocumentTileState();
}

class _OnboardingDocumentTileState extends ConsumerState<OnboardingDocumentTile> {
  bool _uploading = false;
  DateTime? _expiry;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _expiry = widget.existing?.expiryDate;
  }

  bool get _isProfilePhoto => widget.docType == DocumentType.profilePhoto;

  Future<void> _uploadBytes(Uint8List bytes, String fileName) async {
    if (widget.docType.needsExpiry && _expiry == null) {
      throw StateError('Set an expiry date for ${widget.docType.label}.');
    }
    await ref.read(onboardingRepositoryProvider).uploadDocument(
          docType: widget.docType,
          fileBytes: bytes,
          fileName: fileName,
          expiryDate: widget.docType.needsExpiry ? _expiry : null,
        );
    ref.invalidate(onboardingBundleProvider);
    ref.invalidate(driverProfileProvider);
    ref.read(driverRouteGuardProvider).refresh();
    widget.onUploaded();
  }

  Future<void> _confirmRemove() async {
    final existing = widget.existing;
    if (existing?.fileUrl == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${widget.docType.label}?'),
        content: const Text(
          'This clears the uploaded file so you can upload a new one. '
          'Your operator will need to review the replacement.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref.read(onboardingRepositoryProvider).removeDocument(widget.docType);
      ref.invalidate(onboardingBundleProvider);
      ref.invalidate(driverProfileProvider);
      await ref.read(driverRouteGuardProvider).refresh();
      widget.onUploaded();
      if (mounted) {
        setState(() => _expiry = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.docType.label} removed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatOnboardingUploadError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _runUpload(Future<void> Function() action) async {
    setState(() => _uploading = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.docType.label} uploaded')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(formatOnboardingUploadError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _takePhoto() async {
    await _runUpload(() async {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      final name = sanitizeUploadFileName(photo.name);
      await _uploadBytes(bytes, name.endsWith('.jpg') ? name : '$name.jpg');
    });
  }

  Future<void> _pickGallery() async {
    await _runUpload(() async {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      await _uploadBytes(bytes, sanitizeUploadFileName(photo.name));
    });
  }

  Future<void> _pickFile() async {
    await _runUpload(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf', 'heic', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) throw StateError('Could not read file.');
      await _uploadBytes(bytes, sanitizeUploadFileName(file.name));
    });
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 15)),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  bool _looksLikeImageUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.webp') ||
        lower.contains('.heic');
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    final uploaded = existing?.fileUrl != null && existing!.status.isUploaded;
    final fmt = DateFormat.yMMMd();
    final previewUrl = existing?.fileUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.ecoCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.docType.label, style: AppTextStyles.body),
              ),
              if (uploaded)
                const Icon(Icons.check_circle, color: AppColors.accent, size: 20),
            ],
          ),
          if (widget.docType == DocumentType.profilePhoto)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Clear face photo — operators use this on your driver profile.',
                style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
              ),
            ),
          if (existing?.fileName != null) ...[
            const SizedBox(height: 4),
            Text(
              existing!.fileName!,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
            ),
          ],
          if (uploaded && _looksLikeImageUrl(previewUrl)) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                previewUrl!,
                height: widget.docType == DocumentType.profilePhoto ? 120 : 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (existing?.status == DocumentStatus.rejected &&
              existing?.adminNotes != null) ...[
            const SizedBox(height: 6),
            Text(
              'Rejected: ${existing!.adminNotes}',
              style: AppTextStyles.body.copyWith(color: AppColors.error, fontSize: 12),
            ),
          ],
          if (widget.docType.needsExpiry) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _expiry != null ? 'Expires ${fmt.format(_expiry!)}' : 'Expiry date required',
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                  ),
                ),
                TextButton(onPressed: _uploading ? null : _pickExpiry, child: const Text('Set expiry')),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _UploadChip(
                icon: Icons.photo_camera_outlined,
                label: uploaded ? 'Replace (camera)' : 'Camera',
                loading: _uploading,
                onTap: _takePhoto,
              ),
              _UploadChip(
                icon: Icons.photo_library_outlined,
                label: uploaded ? 'Replace (gallery)' : 'Gallery',
                loading: _uploading,
                onTap: _pickGallery,
              ),
              if (!_isProfilePhoto)
                _UploadChip(
                  icon: Icons.upload_file_outlined,
                  label: uploaded ? 'Replace file' : 'PDF / file',
                  loading: _uploading,
                  onTap: _pickFile,
                ),
              if (uploaded)
                _UploadChip(
                  icon: Icons.delete_outline,
                  label: 'Remove',
                  loading: _uploading,
                  onTap: _confirmRemove,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadChip extends StatelessWidget {
  const _UploadChip({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onTap,
      icon: loading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
