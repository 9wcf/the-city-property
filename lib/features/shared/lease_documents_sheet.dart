import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:the_city_property/core/widgets/app_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/system_insets.dart';
import '../../core/widgets/premium_widgets.dart';
import '../../data/models.dart';

class LeaseDocumentsSheet extends ConsumerStatefulWidget {
  const LeaseDocumentsSheet({
    super.key,
    required this.lease,
    this.tenantName,
    this.canUpload = true,
  });

  final Lease lease;
  final String? tenantName;
  final bool canUpload;

  static Future<void> show(
    BuildContext context, {
    required Lease lease,
    String? tenantName,
    bool canUpload = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LeaseDocumentsSheet(
        lease: lease,
        tenantName: tenantName,
        canUpload: canUpload,
      ),
    );
  }

  @override
  ConsumerState<LeaseDocumentsSheet> createState() =>
      _LeaseDocumentsSheetState();
}

class _LeaseDocumentsSheetState extends ConsumerState<LeaseDocumentsSheet> {
  late Future<List<LeaseDocument>> _future;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<LeaseDocument>> _load() =>
      ref.read(repositoryProvider).leaseDocuments(widget.lease.id);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _showPickOptions(String kind) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.gold),
              title: const Text(
                'اختيار صور من المعرض',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndUpload(kind, fromCamera: false);
              },
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: AppColors.gold),
                title: const Text(
                  'التقاط صورة بالكاميرا',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUpload(kind, fromCamera: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUpload(String kind, {required bool fromCamera}) async {
    if (_uploading) return;
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (fromCamera) {
        final image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2400,
        );
        files = image == null ? const [] : [image];
      } else {
        files = await picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2400,
        );
      }
      if (files.isEmpty || !mounted) return;

      setState(() => _uploading = true);
      final result = await ref.read(repositoryProvider).uploadLeaseDocuments(
            leaseId: widget.lease.id,
            tenantId: widget.lease.tenantId,
            apartmentId: widget.lease.apartmentId,
            kind: kind,
            files: files,
          );
      if (!mounted) return;
      setState(() => _uploading = false);
      if (result.failed > 0) {
        showError(
          context,
          'تم رفع ${result.uploaded} صورة وتعذر رفع ${result.failed} صورة',
        );
      } else {
        showSuccess(context, 'تم رفع ${result.uploaded} صورة بنجاح');
      }
      _reload();
    } catch (error) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showError(context, 'تعذر رفع الصور: ${friendlyError(error)}');
    }
  }

  Future<void> _deleteDocument(LeaseDocument document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.navy800,
        title: const Text(
          'حذف الصورة',
          style: TextStyle(fontFamily: 'Tajawal', color: AppColors.textPrimary),
        ),
        content: const Text(
          'سيتم حذف هذه الصورة نهائياً. هل تريد المتابعة؟',
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(repositoryProvider).deleteLeaseDocument(document);
      if (!mounted) return;
      showSuccess(context, 'تم حذف الصورة');
      _reload();
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _openDocument(LeaseDocument document) async {
    final url = document.signedUrl;
    if (url == null) {
      showError(context, 'رابط الصورة غير متاح، حدّث الصفحة وحاول مجدداً');
      return;
    }
    final uri = Uri.tryParse(url);
    if (!document.isImage || uri == null) {
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.navy900,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      document.fileName ?? 'صورة المستمسك',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      child: CircularProgressIndicator(color: AppColors.gold),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Icon(
                      Icons.broken_image_rounded,
                      size: 56,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () => launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('فتح في المتصفح'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Container(
      height: height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: withSystemBottomInset(
        context,
        const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.folder_copy_rounded, color: AppColors.gold),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'المستمسكات وصور العقد',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.tenantName != null)
                      Text(
                        widget.tenantName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded,
                    color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: LinearProgressIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.navy700,
              ),
            ),
          Expanded(
            child: FutureBuilder<List<LeaseDocument>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      friendlyError(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  );
                }
                final documents = snapshot.data ?? const <LeaseDocument>[];
                return ListView(
                  children: [
                    _buildGroup('tenant', documents),
                    const SizedBox(height: AppSpacing.lg),
                    _buildGroup('contract', documents),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String kind, List<LeaseDocument> documents) {
    final items = documents.where((document) => document.kind == kind).toList();
    final isContract = kind == 'contract';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              isContract ? Icons.description_rounded : Icons.badge_rounded,
              size: 18,
              color: AppColors.gold,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                isContract ? 'صور عقد الإيجار' : 'مستمسكات المستأجر',
                style: const TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (widget.canUpload)
              TextButton.icon(
                onPressed: _uploading ? null : () => _showPickOptions(kind),
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                label: const Text('إضافة صور'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.navy700.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: const Text(
              'لم تُرفع صور بعد',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) => _DocumentTile(
              document: items[index],
              onOpen: () => _openDocument(items[index]),
              onDelete: widget.canUpload
                  ? () => _deleteDocument(items[index])
                  : null,
            ),
          ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.document,
    required this.onOpen,
    this.onDelete,
  });

  final LeaseDocument document;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final url = document.signedUrl;
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: AppColors.navy700,
              child: !document.isImage || url == null
                  ? const Center(
                      child: Icon(
                        Icons.picture_as_pdf_rounded,
                        color: AppColors.textSecondary,
                        size: 28,
                      ),
                    )
                  : null,
            ),
            if (document.isImage && url != null)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.textMuted,
                    size: 28,
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: Colors.black54,
                child: Text(
                  document.fileName ?? 'صورة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 8,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (onDelete != null)
              Positioned(
                top: 4,
                left: 4,
                child: GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
