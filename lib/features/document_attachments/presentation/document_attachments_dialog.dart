import 'dart:io';

import 'package:file_picker/file_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../data/document_attachments_repository.dart';
import '../models/document_attachment_item.dart';

final documentAttachmentsRepositoryProvider =
    Provider<DocumentAttachmentsRepository>(
      (ref) => DocumentAttachmentsRepository(ref.watch(apiClientProvider)),
    );

class DocumentAttachmentsDialog extends ConsumerStatefulWidget {
  const DocumentAttachmentsDialog({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.title,
    required this.canModify,
  });

  final String entityType;
  final String entityId;
  final String title;
  final bool canModify;

  @override
  ConsumerState<DocumentAttachmentsDialog> createState() =>
      _DocumentAttachmentsDialogState();
}

class _DocumentAttachmentsDialogState
    extends ConsumerState<DocumentAttachmentsDialog> {
  late Future<List<DocumentAttachmentItem>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<DocumentAttachmentItem>> _load() {
    return ref
        .read(documentAttachmentsRepositoryProvider)
        .fetch(entityType: widget.entityType, entityId: widget.entityId);
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  Future<void> _upload() async {
    final result = await picker.FilePicker.pickFiles(
      type: picker.FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      _showSnack('حجم الملف يجب أن لا يتجاوز 10MB.');
      return;
    }

    await _runBusy(() async {
      await ref
          .read(documentAttachmentsRepositoryProvider)
          .upload(
            entityType: widget.entityType,
            entityId: widget.entityId,
            file: file,
          );
      _showSnack('تم رفع المرفق بنجاح.');
      _refresh();
    });
  }

  Future<void> _download(DocumentAttachmentItem item) async {
    final path = await picker.FilePicker.saveFile(
      dialogTitle: 'حفظ المرفق',
      fileName: item.originalFileName,
    );
    if (path == null || path.isEmpty) {
      return;
    }

    await _runBusy(() async {
      final bytes = await ref
          .read(documentAttachmentsRepositoryProvider)
          .download(item.id);
      await File(path).writeAsBytes(bytes, flush: true);
      _showSnack('تم حفظ المرفق.');
    });
  }

  Future<void> _delete(DocumentAttachmentItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المرفق'),
        content: Text('هل تريد حذف المرفق "${item.originalFileName}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await _runBusy(() async {
      await ref.read(documentAttachmentsRepositoryProvider).delete(item.id);
      _showSnack('تم حذف المرفق.');
      _refresh();
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on AppException catch (exception) {
      _showSnack(exception.message);
    } catch (exception) {
      _showSnack('حدث خطأ غير متوقع: $exception');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 680,
        height: 430,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('PDF أو صورة كتاب رسمي مرتبطة بالسجل الحالي.'),
                ),
                if (widget.canModify)
                  FilledButton.icon(
                    onPressed: _busy ? null : _upload,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('إضافة مرفق'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<DocumentAttachmentItem>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('تعذر تحميل المرفقات: ${snapshot.error}'),
                    );
                  }
                  final items = snapshot.data ?? const [];
                  if (items.isEmpty) {
                    return const Center(child: Text('لا توجد مرفقات بعد.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final date = DateTime.tryParse(item.createdAt);
                      return ListTile(
                        leading: Icon(
                          item.contentType.contains('pdf')
                              ? Icons.picture_as_pdf_outlined
                              : Icons.image_outlined,
                        ),
                        title: Text(item.originalFileName),
                        subtitle: Text(
                          '${_formatSize(item.fileSize)}'
                          '${date == null ? '' : ' - ${formatter.format(date.toLocal())}'}',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'تنزيل',
                              onPressed: _busy ? null : () => _download(item),
                              icon: const Icon(Icons.download_outlined),
                            ),
                            if (widget.canModify)
                              IconButton(
                                tooltip: 'حذف',
                                onPressed: _busy ? null : () => _delete(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes بايت';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
