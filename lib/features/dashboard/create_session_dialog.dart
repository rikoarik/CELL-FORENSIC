import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Simple center-sheet to create a learning session (judul + kode gabung).
///
/// Content version and session status use fixed defaults for now.
class CreateSessionDialog extends StatefulWidget {
  const CreateSessionDialog({
    required this.repository,
    super.key,
  });

  final DashboardSessionRepository repository;

  static Future<LearningSession?> show(
    BuildContext context, {
    required DashboardSessionRepository repository,
  }) {
    return showDialog<LearningSession>(
      context: context,
      barrierColor: DesignTokens.navy.withValues(alpha: 0.45),
      builder: (_) => CreateSessionDialog(repository: repository),
    );
  }

  @override
  State<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<CreateSessionDialog> {
  /// DB column still required; not shown in teacher UI.
  static const _legacyStationDurationSeconds = 300;

  final _titleController = TextEditingController();
  final _codeController = TextEditingController();
  String? _contentVersionId;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_onPreviewChanged);
    _codeController.addListener(_onPreviewChanged);
    _loadDefaults();
  }

  void _onPreviewChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_onPreviewChanged)
      ..dispose();
    _codeController
      ..removeListener(_onPreviewChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final versions = await widget.repository.loadContentVersions();
      if (!mounted) return;
      setState(() {
        _contentVersionId =
            versions.isNotEmpty ? versions.first.id : null;
        _loading = false;
        if (_contentVersionId == null) {
          _error = 'Belum ada konten terbit. Hubungi admin konten.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat konten: $e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final contentId = _contentVersionId;
    if (contentId == null) {
      setState(() => _error = 'Belum ada konten terbit.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = await widget.repository.createSession(
        title: _titleController.text,
        joinCode: _codeController.text,
        contentVersionId: contentId,
        stationDurationSeconds: _legacyStationDurationSeconds,
        status: SessionStatus.active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(session);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError ? e.message : 'Gagal membuat sesi: $e';
        _saving = false;
      });
    }
  }

  String get _previewTitle {
    final t = _titleController.text.trim();
    return t.isEmpty ? 'Judul sesi' : t;
  }

  String get _previewCode {
    final c = _codeController.text.trim().toUpperCase();
    return c.isEmpty ? 'KODE' : c;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    final wide = media.width >= 640;

    return Dialog(
      key: const Key('create-session-sheet'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: media.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Buat Sesi',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Isi judul dan kode gabung untuk siswa.',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: DesignTokens.inkMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(48),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 5, child: _buildForm()),
                                const SizedBox(width: 20),
                                Expanded(flex: 4, child: _buildPreview()),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildForm(),
                                const SizedBox(height: 20),
                                _buildPreview(),
                              ],
                            ),
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  if (_error != null)
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton(
                    onPressed:
                        _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('create-session-submit'),
                    onPressed: _saving ||
                            _loading ||
                            _contentVersionId == null
                        ? null
                        : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Buat sesi'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('create-session-title'),
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Judul sesi',
            hintText: 'mis. Praktikum Sel Kelas X',
          ),
          enabled: !_saving,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: DesignTokens.spaceMd),
        TextField(
          key: const Key('create-session-join-code'),
          controller: _codeController,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: const InputDecoration(
            labelText: 'Kode gabung',
            hintText: 'mis. CELL02',
            helperText: 'Huruf/angka, tanpa spasi',
          ),
          enabled: !_saving,
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Container(
      key: const Key('create-session-preview'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: DesignTokens.surface,
        borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
        border: Border.all(color: DesignTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pratinjau',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: DesignTokens.inkMuted,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 12),
          Text(
            _previewTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: DesignTokens.navy,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: DesignTokens.navy,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  'KODE GABUNG',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _previewCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Siswa masukkan kode ini di app atau web siswa.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: DesignTokens.inkMuted,
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}
