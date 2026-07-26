import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal form to create a learning session (E9).
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
      builder: (_) => CreateSessionDialog(repository: repository),
    );
  }

  @override
  State<CreateSessionDialog> createState() => _CreateSessionDialogState();
}

class _CreateSessionDialogState extends State<CreateSessionDialog> {
  final _titleController = TextEditingController();
  final _codeController = TextEditingController();
  final _durationController = TextEditingController(text: '300');
  List<ContentVersionOption> _versions = const [];
  String? _contentVersionId;
  SessionStatus _status = SessionStatus.active;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _codeController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    try {
      final versions = await widget.repository.loadContentVersions();
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _contentVersionId =
            versions.isNotEmpty ? versions.first.id : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat versi konten: $e';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    final contentId = _contentVersionId;
    if (contentId == null) {
      setState(() => _error = 'Tidak ada content version terbit.');
      return;
    }
    final duration = int.tryParse(_durationController.text.trim());
    if (duration == null) {
      setState(() => _error = 'Durasi tidak valid.');
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
        stationDurationSeconds: duration,
        status: _status,
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buat Sesi Baru'),
      content: SizedBox(
        width: 420,
        child: _loading
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const Key('create-session-title'),
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Judul sesi',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_saving,
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    TextField(
                      key: const Key('create-session-join-code'),
                      controller: _codeController,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[A-Za-z0-9-]'),
                        ),
                        LengthLimitingTextInputFormatter(16),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Kode gabung',
                        hintText: 'mis. CELL02',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_saving,
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    DropdownButtonFormField<String>(
                      key: const Key('create-session-content-version'),
                      // ignore: deprecated_member_use
                      value: _contentVersionId,
                      decoration: const InputDecoration(
                        labelText: 'Versi konten',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final v in _versions)
                          DropdownMenuItem(
                            value: v.id,
                            child: Text(v.versionCode),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                              setState(() => _contentVersionId = value),
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    TextField(
                      key: const Key('create-session-duration'),
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Durasi stasiun (detik)',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_saving,
                    ),
                    const SizedBox(height: DesignTokens.spaceMd),
                    DropdownButtonFormField<SessionStatus>(
                      key: const Key('create-session-status'),
                      // ignore: deprecated_member_use
                      value: _status,
                      decoration: const InputDecoration(
                        labelText: 'Status awal',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: SessionStatus.draft,
                          child: Text('Draft'),
                        ),
                        DropdownMenuItem(
                          value: SessionStatus.active,
                          child: Text('Aktif'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: DesignTokens.spaceMd),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          key: const Key('create-session-submit'),
          onPressed: _saving || _loading ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
