import 'package:cell_forensic/core/config/app_flavor.dart';
import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/auth/teacher_auth_gate.dart';
import 'package:cell_forensic/features/dashboard/create_session_dialog.dart';
import 'package:cell_forensic/features/dashboard/csv_download.dart';
import 'package:cell_forensic/features/dashboard/dashboard_csv_exporter.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:cell_forensic/features/dashboard/group_detail_screen.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key, this.repository});

  /// Injected in tests; defaults to Supabase-backed loader.
  final DashboardSessionRepository? repository;

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  late final DashboardSessionRepository _repository =
      widget.repository ?? const SupabaseDashboardSessionRepository();

  late Future<List<DashboardSessionSnapshot>> _future;
  String? _exportingSessionId;
  String? _statusUpdatingSessionId;

  @override
  void initState() {
    super.initState();
    _future = _repository.loadActiveSessions();
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repository.loadActiveSessions();
    });
    await _future;
  }

  Future<void> _createSession() async {
    final created = await CreateSessionDialog.show(
      context,
      repository: _repository,
    );
    if (created == null || !mounted) return;
    await _reload();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sesi ${created.joinCode} dibuat (${created.status.name}).',
        ),
      ),
    );
  }

  Future<void> _setStatus(
    DashboardSessionSnapshot snapshot,
    SessionStatus status,
  ) async {
    setState(() => _statusUpdatingSessionId = snapshot.session.id);
    try {
      await _repository.updateSessionStatus(
        sessionId: snapshot.session.id,
        status: status,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == SessionStatus.active
                ? 'Sesi diaktifkan — siswa dapat bergabung.'
                : 'Sesi ditutup — penulisan siswa dikunci.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah status: $e')),
      );
    } finally {
      if (mounted) setState(() => _statusUpdatingSessionId = null);
    }
  }

  Future<void> _exportCsv(DashboardSessionSnapshot snapshot) async {
    setState(() => _exportingSessionId = snapshot.session.id);
    try {
      final rows = await _repository.loadExportRows(snapshot.session.id);
      final csv = DashboardCsvExporter.build(rows);
      final filename =
          'cell-forensic-${snapshot.session.joinCode.toLowerCase()}.csv';
      final downloaded = downloadCsvFile(csv, filename);
      if (!downloaded) {
        await Clipboard.setData(ClipboardData(text: csv));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'CSV diunduh ($filename)'
                : 'CSV disalin ke papan klip (${rows.length} baris)',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal ekspor CSV: $e')),
      );
    } finally {
      if (mounted) setState(() => _exportingSessionId = null);
    }
  }

  void _openGroup(DashboardSessionSnapshot snapshot, int groupIndex) {
    final group = snapshot.groups[groupIndex];
    final profile = TeacherAuthScope.maybeOf(context)?.profile;
    // Without an auth scope (widget tests), allow manage actions.
    final canManage = profile == null ||
        snapshot.session.canBeManagedBy(
          actorId: profile.id,
          actorRole: profile.role,
        );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupDetailScreen(
          repository: _repository,
          session: snapshot.session,
          group: group,
          canManage: canManage,
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final scope = TeacherAuthScope.maybeOf(context);
    await scope?.authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = TeacherAuthScope.maybeOf(context)?.profile;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('create-session-fab'),
        onPressed: _createSession,
        icon: const Icon(Icons.add),
        label: const Text('Buat Sesi'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= DesignTokens.dashboardBreakpoint;
            return Row(
              key: Key(
                wide ? 'dashboard-wide-layout' : 'dashboard-compact-layout',
              ),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (wide)
                  Container(
                    width: DesignTokens.dashboardSidebar,
                    height: double.infinity,
                    color: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.all(DesignTokens.spaceLg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cell Forensic',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spaceSm),
                        Text(
                          'Dashboard Guru · ${AppFlavor.current.label}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                        if (profile != null) ...[
                          const SizedBox(height: DesignTokens.spaceMd),
                          Text(
                            profile.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            profile.role,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: DesignTokens.spaceXl),
                        Text(
                          'Sesi praktikum',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Buat · Aktifkan · Tutup · Nilai · CSV',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          key: const Key('teacher-logout-button'),
                          onPressed: _signOut,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Keluar'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(
                        wide ? DesignTokens.spaceXl : 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!wide) ...[
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Cell Forensic',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    key: const Key('teacher-logout-button'),
                                    onPressed: _signOut,
                                    tooltip: 'Keluar',
                                    icon: const Icon(Icons.logout),
                                  ),
                                ],
                              ),
                              if (profile != null)
                                Text(
                                  '${profile.fullName} · ${profile.role}',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              const SizedBox(height: DesignTokens.spaceLg),
                            ],
                            Text(
                              'Ringkasan Sesi',
                              style:
                                  Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: DesignTokens.spaceSm),
                            Text(
                              SupabaseConfig.isConfigured
                                  ? 'Pantau sesi, aktifkan/tutup kelas, dan nilai jawaban siswa.'
                                  : 'Mode lokal — hubungkan Supabase untuk data live.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 28),
                            FutureBuilder<List<DashboardSessionSnapshot>>(
                              future: _future,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Padding(
                                    padding: EdgeInsets.all(32),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                if (snapshot.hasError) {
                                  return _InfoCard(
                                    icon: Icons.error_outline,
                                    title: 'Gagal memuat sesi',
                                    body: '${snapshot.error}',
                                  );
                                }
                                final sessions = snapshot.data ?? const [];
                                if (sessions.isEmpty) {
                                  return const _InfoCard(
                                    icon: Icons.science_outlined,
                                    title: 'Belum ada sesi',
                                    body:
                                        'Buat sesi baru dengan tombol Buat Sesi, '
                                        'atau aktifkan sesi demo CELL01.',
                                  );
                                }
                                return Column(
                                  children: [
                                    for (final item in sessions) ...[
                                      _SessionCard(
                                        snapshot: item,
                                        canManage: profile == null ||
                                            item.session.canBeManagedBy(
                                              actorId: profile.id,
                                              actorRole: profile.role,
                                            ),
                                        exporting: _exportingSessionId ==
                                            item.session.id,
                                        statusBusy: _statusUpdatingSessionId ==
                                            item.session.id,
                                        onExport: () => _exportCsv(item),
                                        onActivate: () => _setStatus(
                                          item,
                                          SessionStatus.active,
                                        ),
                                        onClose: () => _setStatus(
                                          item,
                                          SessionStatus.closed,
                                        ),
                                        onOpenGroup: (index) =>
                                            _openGroup(item, index),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ringkasan sesi praktikum',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Icon(icon, size: 40),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(body, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.snapshot,
    required this.onExport,
    required this.onOpenGroup,
    required this.onActivate,
    required this.onClose,
    this.canManage = true,
    this.exporting = false,
    this.statusBusy = false,
  });

  final DashboardSessionSnapshot snapshot;
  final VoidCallback onExport;
  final VoidCallback onActivate;
  final VoidCallback onClose;
  final ValueChanged<int> onOpenGroup;
  final bool canManage;
  final bool exporting;
  final bool statusBusy;

  @override
  Widget build(BuildContext context) {
    final session = snapshot.session;
    final title =
        session.title.isEmpty ? 'Sesi ${session.joinCode}' : session.title;
    final isActive = session.status == SessionStatus.active;
    final isClosed = session.status == SessionStatus.closed;

    return Semantics(
      label: 'Ringkasan sesi praktikum',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: Key('export-csv-${session.id}'),
                    onPressed: exporting ? null : onExport,
                    icon: exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('Ekspor CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Kode: ${session.joinCode} · ${session.status.name} · '
                '${snapshot.groups.length} kelompok'
                '${snapshot.pendingReviewCount > 0 ? ' · ${snapshot.pendingReviewCount} menunggu review' : ''}',
              ),
              if (!canManage) ...[
                const SizedBox(height: 8),
                Text(
                  session.teacherId == null
                      ? 'Sesi demo tanpa pemilik — Aktifkan/Tutup/nilai hanya '
                          'untuk sesi yang Anda buat (atau tetapkan teacher_id).'
                      : 'Sesi milik guru lain — hanya lihat (baca saja).',
                  key: Key('session-readonly-${session.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
              const SizedBox(height: 12),
              if (canManage)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isActive)
                      FilledButton.icon(
                        key: Key('activate-session-${session.id}'),
                        onPressed: statusBusy ? null : onActivate,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Aktifkan'),
                      ),
                    if (!isClosed)
                      OutlinedButton.icon(
                        key: Key('close-session-${session.id}'),
                        onPressed: statusBusy ? null : onClose,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Tutup Sesi'),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              Text(
                'Kelompok (${snapshot.groups.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (snapshot.groups.isEmpty)
                const Text('Belum ada kelompok yang bergabung.')
              else
                for (var i = 0; i < snapshot.groups.length; i++)
                  ListTile(
                    key: Key('group-tile-${snapshot.groups[i].id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(snapshot.groups[i].name),
                    subtitle: Text(
                      snapshot.groups[i].members.isEmpty
                          ? 'Belum ada anggota'
                          : snapshot.groups[i].members
                              .map((m) => m.displayName)
                              .join(', '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => onOpenGroup(i),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
