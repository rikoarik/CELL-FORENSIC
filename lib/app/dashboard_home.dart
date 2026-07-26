import 'package:cell_forensic/core/config/app_flavor.dart';
import 'package:cell_forensic/core/supabase/supabase_config.dart';
import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/auth/teacher_auth_gate.dart';
import 'package:cell_forensic/features/auth/teacher_profile.dart';
import 'package:cell_forensic/features/dashboard/create_session_dialog.dart';
import 'package:cell_forensic/features/dashboard/csv_download.dart';
import 'package:cell_forensic/features/dashboard/dashboard_csv_exporter.dart';
import 'package:cell_forensic/features/dashboard/dashboard_session_repository.dart';
import 'package:cell_forensic/features/dashboard/group_detail_screen.dart';
import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum _DashboardSection { overview, reviewQueue, sessions }

enum _StatusFilter { all, active, draft, closed, paused }

/// Teacher ops console: session overview, review queue, and group drill-down.
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

  _DashboardSection _section = _DashboardSection.overview;
  _StatusFilter _statusFilter = _StatusFilter.all;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _future = _repository.loadActiveSessions();
    _searchController.addListener(() {
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    setState(() => _section = _DashboardSection.sessions);
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
                ? 'Sesi diaktifkan. Siswa dapat bergabung.'
                : 'Sesi ditutup. Penulisan siswa dikunci.',
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

  List<DashboardSessionSnapshot> _filterSessions(
    List<DashboardSessionSnapshot> sessions,
  ) {
    return sessions.where((snap) {
      final status = snap.session.status;
      final statusOk = switch (_statusFilter) {
        _StatusFilter.all => true,
        _StatusFilter.active => status == SessionStatus.active,
        _StatusFilter.draft => status == SessionStatus.draft,
        _StatusFilter.closed => status == SessionStatus.closed,
        _StatusFilter.paused => status == SessionStatus.paused,
      };
      if (!statusOk) return false;
      if (_searchQuery.isEmpty) return true;
      final title = snap.session.title.toLowerCase();
      final code = snap.session.joinCode.toLowerCase();
      final groupHit = snap.groups.any(
        (g) =>
            g.name.toLowerCase().contains(_searchQuery) ||
            g.members.any(
              (m) => m.displayName.toLowerCase().contains(_searchQuery),
            ),
      );
      return title.contains(_searchQuery) ||
          code.contains(_searchQuery) ||
          groupHit;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final profile = TeacherAuthScope.maybeOf(context)?.profile;

    return Scaffold(
      backgroundColor: DesignTokens.surface,
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
                  _DashboardSidebar(
                    profile: profile,
                    section: _section,
                    onSection: (s) => setState(() => _section = s),
                    onSignOut: _signOut,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            wide ? DesignTokens.spaceXl : 20,
                            wide ? DesignTokens.spaceXl : 16,
                            wide ? DesignTokens.spaceXl : 20,
                            DesignTokens.spaceXl,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1120),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!wide) ...[
                                    _CompactHeader(
                                      profile: profile,
                                      section: _section,
                                      onSection: (s) =>
                                          setState(() => _section = s),
                                      onSignOut: _signOut,
                                    ),
                                    const SizedBox(
                                      height: DesignTokens.spaceLg,
                                    ),
                                  ],
                                  FutureBuilder<List<DashboardSessionSnapshot>>(
                                    future: _future,
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const _DashboardLoading();
                                      }
                                      if (snapshot.hasError) {
                                        return _InfoCard(
                                          icon: Icons.error_outline,
                                          title: 'Gagal memuat sesi',
                                          body: '${snapshot.error}',
                                          tone: _InfoTone.error,
                                          actionLabel: 'Coba lagi',
                                          onAction: _reload,
                                        );
                                      }
                                      final sessions =
                                          snapshot.data ?? const [];
                                      return _DashboardBody(
                                        section: _section,
                                        sessions: sessions,
                                        filtered: _filterSessions(sessions),
                                        searchController: _searchController,
                                        statusFilter: _statusFilter,
                                        onStatusFilter: (f) => setState(
                                          () => _statusFilter = f,
                                        ),
                                        onSection: (s) => setState(
                                          () => _section = s,
                                        ),
                                        exportingSessionId:
                                            _exportingSessionId,
                                        statusUpdatingSessionId:
                                            _statusUpdatingSessionId,
                                        profile: profile,
                                        onCreateSession: _createSession,
                                        onExport: _exportCsv,
                                        onActivate: (s) => _setStatus(
                                          s,
                                          SessionStatus.active,
                                        ),
                                        onClose: (s) => _setStatus(
                                          s,
                                          SessionStatus.closed,
                                        ),
                                        onOpenGroup: _openGroup,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.section,
    required this.sessions,
    required this.filtered,
    required this.searchController,
    required this.statusFilter,
    required this.onStatusFilter,
    required this.onSection,
    required this.exportingSessionId,
    required this.statusUpdatingSessionId,
    required this.profile,
    required this.onCreateSession,
    required this.onExport,
    required this.onActivate,
    required this.onClose,
    required this.onOpenGroup,
  });

  final _DashboardSection section;
  final List<DashboardSessionSnapshot> sessions;
  final List<DashboardSessionSnapshot> filtered;
  final TextEditingController searchController;
  final _StatusFilter statusFilter;
  final ValueChanged<_StatusFilter> onStatusFilter;
  final ValueChanged<_DashboardSection> onSection;
  final String? exportingSessionId;
  final String? statusUpdatingSessionId;
  final TeacherProfile? profile;
  final VoidCallback onCreateSession;
  final void Function(DashboardSessionSnapshot) onExport;
  final void Function(DashboardSessionSnapshot) onActivate;
  final void Function(DashboardSessionSnapshot) onClose;
  final void Function(DashboardSessionSnapshot, int) onOpenGroup;

  @override
  Widget build(BuildContext context) {
    final groupCount =
        sessions.fold<int>(0, (sum, s) => sum + s.groups.length);
    final memberCount =
        sessions.fold<int>(0, (sum, s) => sum + s.memberCount);
    final pendingCount =
        sessions.fold<int>(0, (sum, s) => sum + s.pendingReviewCount);
    final activeCount = sessions
        .where((s) => s.session.status == SessionStatus.active)
        .length;
    final reviewSessions =
        sessions.where((s) => s.pendingReviewCount > 0).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          section: section,
          onCreateSession: onCreateSession,
        ),
        const SizedBox(height: DesignTokens.spaceSm),
        Text(
          SupabaseConfig.isConfigured
              ? 'Konsol operasi kelas: aktifkan sesi, pantau kelompok, '
                  'nilai esai, ekspor CSV.'
              : 'Supabase belum terhubung. Hubungkan proyek untuk memuat sesi live.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (sessions.isEmpty)
          _InfoCard(
            icon: Icons.science_outlined,
            title: 'Belum ada sesi',
            body: SupabaseConfig.isConfigured
                ? 'Buat sesi baru, bagikan kode gabung ke siswa, lalu pantau '
                    'progres kelompok dan antrian review di sini.'
                : 'Belum ada data sesi karena backend belum dikonfigurasi. '
                    'Set SUPABASE_URL dan SUPABASE_ANON_KEY, lalu muat ulang.',
            actionLabel: SupabaseConfig.isConfigured ? 'Buat Sesi' : null,
            onAction: SupabaseConfig.isConfigured ? onCreateSession : null,
          )
        else ...[
          _OverviewStats(
            sessionCount: sessions.length,
            activeCount: activeCount,
            groupCount: groupCount,
            memberCount: memberCount,
            pendingReviewCount: pendingCount,
            onReviewTap: pendingCount > 0
                ? () => onSection(_DashboardSection.reviewQueue)
                : null,
          ),
          const SizedBox(height: 20),
          if (section == _DashboardSection.overview) ...[
            if (pendingCount > 0) ...[
              _AttentionBanner(
                pendingCount: pendingCount,
                sessionCount: reviewSessions.length,
                onOpenQueue: () => onSection(_DashboardSection.reviewQueue),
              ),
              const SizedBox(height: 20),
            ],
            _ToolbarRow(
              searchController: searchController,
              statusFilter: statusFilter,
              onStatusFilter: onStatusFilter,
              showSearch: true,
            ),
            const SizedBox(height: 16),
            _SessionList(
              sessions: filtered.take(4).toList(growable: false),
              emptyTitle: 'Tidak ada sesi cocok filter',
              emptyBody: 'Ubah pencarian atau filter status.',
              profile: profile,
              exportingSessionId: exportingSessionId,
              statusUpdatingSessionId: statusUpdatingSessionId,
              onExport: onExport,
              onActivate: onActivate,
              onClose: onClose,
              onOpenGroup: onOpenGroup,
            ),
            if (filtered.length > 4) ...[
              const SizedBox(height: 8),
              TextButton(
                key: const Key('dashboard-see-all-sessions'),
                onPressed: () => onSection(_DashboardSection.sessions),
                child: Text('Lihat semua ${filtered.length} sesi'),
              ),
            ],
          ] else if (section == _DashboardSection.reviewQueue) ...[
            if (reviewSessions.isEmpty)
              const _InfoCard(
                icon: Icons.task_alt_outlined,
                title: 'Antrian review kosong',
                body:
                    'Semua jawaban yang butuh penilaian guru sudah dinilai. '
                    'Muat ulang setelah siswa mengumpulkan esai baru.',
              )
            else
              _ReviewQueuePanel(
                sessions: reviewSessions,
                onOpenGroup: onOpenGroup,
              ),
          ] else ...[
            _ToolbarRow(
              searchController: searchController,
              statusFilter: statusFilter,
              onStatusFilter: onStatusFilter,
              showSearch: true,
            ),
            const SizedBox(height: 16),
            _SessionList(
              sessions: filtered,
              emptyTitle: 'Tidak ada sesi cocok filter',
              emptyBody: 'Ubah pencarian atau filter status, lalu coba lagi.',
              profile: profile,
              exportingSessionId: exportingSessionId,
              statusUpdatingSessionId: statusUpdatingSessionId,
              onExport: onExport,
              onActivate: onActivate,
              onClose: onClose,
              onOpenGroup: onOpenGroup,
            ),
          ],
        ],
      ],
    );
  }
}
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.section,
    this.onCreateSession,
  });

  final _DashboardSection section;
  final VoidCallback? onCreateSession;

  @override
  Widget build(BuildContext context) {
    final title = switch (section) {
      _DashboardSection.overview => 'Ringkasan Sesi',
      _DashboardSection.reviewQueue => 'Antrian Review',
      _DashboardSection.sessions => 'Semua Sesi',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(letterSpacing: -0.4),
          ),
        ),
        if (onCreateSession != null)
          FilledButton.icon(
            key: const Key('create-session-fab'),
            onPressed: onCreateSession,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Buat Sesi'),
          ),
      ],
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  const _DashboardSidebar({
    required this.profile,
    required this.section,
    required this.onSection,
    required this.onSignOut,
  });

  final TeacherProfile? profile;
  final _DashboardSection section;
  final ValueChanged<_DashboardSection> onSection;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final signedIn = profile;
    return Container(
      width: DesignTokens.dashboardSidebar,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: DesignTokens.navy,
        border: Border(
          right: BorderSide(color: Color(0xFF243B53), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: DesignTokens.blue.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: DesignTokens.blue.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.biotech_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cell Forensic',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Konsol Guru · ${AppFlavor.current.label}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          if (signedIn != null) ...[
            const SizedBox(height: DesignTokens.spaceLg),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signedIn.fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    signedIn.role.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: DesignTokens.spaceXl),
          Text(
            'Navigasi',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          _NavItem(
            keyName: 'nav-overview',
            label: 'Ringkasan',
            icon: Icons.dashboard_outlined,
            selected: section == _DashboardSection.overview,
            onTap: () => onSection(_DashboardSection.overview),
          ),
          _NavItem(
            keyName: 'nav-review',
            label: 'Antrian Review',
            icon: Icons.rate_review_outlined,
            selected: section == _DashboardSection.reviewQueue,
            onTap: () => onSection(_DashboardSection.reviewQueue),
          ),
          _NavItem(
            keyName: 'nav-sessions',
            label: 'Semua Sesi',
            icon: Icons.layers_outlined,
            selected: section == _DashboardSection.sessions,
            onTap: () => onSection(_DashboardSection.sessions),
          ),
          const Spacer(),
          TextButton.icon(
            key: const Key('teacher-logout-button'),
            onPressed: onSignOut,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String keyName;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: Key(keyName),
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.75),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 14,
                    ),
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

class _CompactHeader extends StatelessWidget {
  const _CompactHeader({
    required this.profile,
    required this.section,
    required this.onSection,
    required this.onSignOut,
  });

  final TeacherProfile? profile;
  final _DashboardSection section;
  final ValueChanged<_DashboardSection> onSection;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final signedIn = profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Cell Forensic',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.navy,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            IconButton(
              key: const Key('teacher-logout-button'),
              onPressed: onSignOut,
              tooltip: 'Keluar',
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        if (signedIn != null)
          Text(
            '${signedIn.fullName} · ${signedIn.role}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                (_DashboardSection.overview, 'Ringkasan'),
                (_DashboardSection.reviewQueue, 'Review'),
                (_DashboardSection.sessions, 'Sesi'),
              ]) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: Key('compact-nav-${entry.$1.name}'),
                    label: Text(entry.$2),
                    selected: section == entry.$1,
                    onSelected: (_) => onSection(entry.$1),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewStats extends StatelessWidget {
  const _OverviewStats({
    required this.sessionCount,
    required this.activeCount,
    required this.groupCount,
    required this.memberCount,
    required this.pendingReviewCount,
    this.onReviewTap,
  });

  final int sessionCount;
  final int activeCount;
  final int groupCount;
  final int memberCount;
  final int pendingReviewCount;
  final VoidCallback? onReviewTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrap = constraints.maxWidth < 720;
        final tiles = [
          _StatTile(
            label: 'Sesi',
            value: '$sessionCount',
            hint: '$activeCount aktif',
            icon: Icons.layers_outlined,
          ),
          _StatTile(
            label: 'Kelompok',
            value: '$groupCount',
            hint: '$memberCount siswa',
            icon: Icons.groups_outlined,
          ),
          _StatTile(
            label: 'Menunggu review',
            value: '$pendingReviewCount',
            hint: pendingReviewCount == 0
                ? 'semua dinilai'
                : 'buka antrian',
            icon: Icons.rate_review_outlined,
            emphasize: pendingReviewCount > 0,
            onTap: onReviewTap,
          ),
        ];
        if (wrap) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                tiles[i],
                if (i < tiles.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    this.emphasize = false,
    this.onTap,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final bool emphasize;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: emphasize
              ? const Color(0xFFF0B429).withValues(alpha: 0.55)
              : DesignTokens.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: emphasize
                  ? const Color(0xFFFFF8E8)
                  : DesignTokens.blue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: emphasize ? const Color(0xFF8D6B0B) : DesignTokens.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: DesignTokens.inkMuted,
                      ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.navy,
                    height: 1.15,
                  ),
                ),
                Text(
                  hint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: DesignTokens.inkMuted),
        ],
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('stat-pending-review'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: child,
      ),
    );
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({
    required this.pendingCount,
    required this.sessionCount,
    required this.onOpenQueue,
  });

  final int pendingCount;
  final int sessionCount;
  final VoidCallback onOpenQueue;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard-attention-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0B429).withValues(alpha: 0.45),
        ),
      ),
          child: Row(
            children: [
              const Icon(Icons.priority_high_rounded, color: Color(0xFF8D6B0B)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$pendingCount jawaban menunggu review di $sessionCount sesi.',
                  style: const TextStyle(
                    color: Color(0xFF8D6B0B),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              TextButton(
                key: const Key('dashboard-open-review-queue'),
                onPressed: onOpenQueue,
                child: const Text('Buka'),
              ),
            ],
          ),
    );
  }
}

class _ToolbarRow extends StatelessWidget {
  const _ToolbarRow({
    required this.searchController,
    required this.statusFilter,
    required this.onStatusFilter,
    required this.showSearch,
  });

  final TextEditingController searchController;
  final _StatusFilter statusFilter;
  final ValueChanged<_StatusFilter> onStatusFilter;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSearch)
          TextField(
            key: const Key('dashboard-search'),
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Cari judul, kode gabung, kelompok, atau siswa…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        if (showSearch) const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const [
                (_StatusFilter.all, 'Semua'),
                (_StatusFilter.active, 'Aktif'),
                (_StatusFilter.draft, 'Draft'),
                (_StatusFilter.paused, 'Dijeda'),
                (_StatusFilter.closed, 'Ditutup'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    key: Key('filter-${entry.$1.name}'),
                    label: Text(entry.$2),
                    selected: statusFilter == entry.$1,
                    onSelected: (_) => onStatusFilter(entry.$1),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionList extends StatelessWidget {
  const _SessionList({
    required this.sessions,
    required this.emptyTitle,
    required this.emptyBody,
    required this.profile,
    required this.exportingSessionId,
    required this.statusUpdatingSessionId,
    required this.onExport,
    required this.onActivate,
    required this.onClose,
    required this.onOpenGroup,
  });

  final List<DashboardSessionSnapshot> sessions;
  final String emptyTitle;
  final String emptyBody;
  final TeacherProfile? profile;
  final String? exportingSessionId;
  final String? statusUpdatingSessionId;
  final void Function(DashboardSessionSnapshot) onExport;
  final void Function(DashboardSessionSnapshot) onActivate;
  final void Function(DashboardSessionSnapshot) onClose;
  final void Function(DashboardSessionSnapshot, int) onOpenGroup;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return _InfoCard(
        icon: Icons.filter_alt_off_outlined,
        title: emptyTitle,
        body: emptyBody,
      );
    }

    return Column(
      children: [
        for (final item in sessions) ...[
          _SessionCard(
            snapshot: item,
            canManage: profile == null ||
                item.session.canBeManagedBy(
                  actorId: profile!.id,
                  actorRole: profile!.role,
                ),
            exporting: exportingSessionId == item.session.id,
            statusBusy: statusUpdatingSessionId == item.session.id,
            onExport: () => onExport(item),
            onActivate: () => onActivate(item),
            onClose: () => onClose(item),
            onOpenGroup: (index) => onOpenGroup(item, index),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ReviewQueuePanel extends StatelessWidget {
  const _ReviewQueuePanel({
    required this.sessions,
    required this.onOpenGroup,
  });

  final List<DashboardSessionSnapshot> sessions;
  final void Function(DashboardSessionSnapshot, int) onOpenGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prioritaskan kelompok dengan esai / skor provisional yang belum dinilai.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        for (final snap in sessions) ...[
          Card(
            key: Key('review-session-${snap.session.id}'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          snap.session.title.isEmpty
                              ? 'Sesi ${snap.session.joinCode}'
                              : snap.session.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      _JoinCodeBadge(code: snap.session.joinCode),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snap.pendingReviewCount} menunggu review · '
                    '${snap.groups.length} kelompok',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < snap.groups.length; i++)
                    if (snap.pendingForGroup(snap.groups[i].id) > 0)
                      ListTile(
                        key: Key(
                          'review-group-${snap.groups[i].id}',
                        ),
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              const Color(0xFFFFF8E8),
                          foregroundColor: const Color(0xFF8D6B0B),
                          child: Text(
                            '${snap.pendingForGroup(snap.groups[i].id)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        title: Text(snap.groups[i].name),
                        subtitle: Text(
                          snap.groups[i].members.isEmpty
                              ? 'Belum ada anggota'
                              : snap.groups[i].members
                                  .map((m) => m.displayName)
                                  .join(', '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onOpenGroup(snap, i),
                      ),
                  if (snap.pendingReviewByGroupId.isEmpty)
                    for (var i = 0; i < snap.groups.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(snap.groups[i].name),
                        subtitle: Text(
                          'Buka detail untuk menilai '
                          '(${snap.pendingReviewCount} di sesi ini)',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onOpenGroup(snap, i),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

enum _InfoTone { neutral, error }

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.tone = _InfoTone.neutral,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final _InfoTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isError = tone == _InfoTone.error;
    return Semantics(
      label: 'Ringkasan sesi praktikum',
      container: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isError
                      ? Theme.of(context).colorScheme.errorContainer
                      : DesignTokens.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: isError
                      ? Theme.of(context).colorScheme.error
                      : DesignTokens.blue,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(body, style: Theme.of(context).textTheme.bodyLarge),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ],
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

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('dashboard-loading'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Sesi',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(letterSpacing: -0.4),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < 3; i++) ...[
          Container(
            height: 88,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DesignTokens.border),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ],
      ],
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
    final groups = snapshot.groups;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _JoinCodeBadge(code: session.joinCode),
                            _StatusBadge(status: session.status),
                            if (snapshot.pendingReviewCount > 0)
                              _MetaChip(
                                icon: Icons.rate_review_outlined,
                                label:
                                    '${snapshot.pendingReviewCount} review',
                                emphasize: true,
                              ),
                            _MetaChip(
                              icon: Icons.groups_outlined,
                              label:
                                  '${snapshot.groups.length} kelompok · ${snapshot.memberCount} siswa',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
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
                    label: const Text('CSV'),
                  ),
                ],
              ),
              if (!canManage) ...[
                const SizedBox(height: 12),
                Text(
                  session.teacherId == null
                      ? 'Sesi tanpa pemilik. Aktifkan/Tutup/nilai hanya '
                          'untuk sesi yang Anda buat (atau tetapkan teacher_id).'
                      : 'Sesi milik guru lain. Hanya lihat (baca saja).',
                  key: Key('session-readonly-${session.id}'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
              const SizedBox(height: 14),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Kelompok (${snapshot.groups.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (snapshot.groups.isNotEmpty)
                    Flexible(
                      child: Text(
                        'Ketuk untuk detail',
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (groups.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DesignTokens.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: DesignTokens.border),
                  ),
                  child: Text(
                    'Belum ada kelompok yang bergabung. Bagikan kode '
                    '${session.joinCode} ke siswa (aplikasi atau web siswa).',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              else
                Container(
                  key: Key('session-groups-${session.id}'),
                  decoration: BoxDecoration(
                    color: DesignTokens.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: DesignTokens.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < groups.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: DesignTokens.border),
                        Material(
                          color: Colors.transparent,
                          child: ListTile(
                            key: Key('group-tile-${groups[i].id}'),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  DesignTokens.blue.withValues(alpha: 0.1),
                              foregroundColor: DesignTokens.blue,
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            title: Text(groups[i].name),
                            subtitle: Text(
                              groups[i].members.isEmpty
                                  ? 'Belum ada anggota'
                                  : groups[i].members
                                      .map((m) => m.displayName)
                                      .join(', '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (snapshot.pendingForGroup(groups[i].id) > 0)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8E8),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${snapshot.pendingForGroup(groups[i].id)} review',
                                      style: const TextStyle(
                                        color: Color(0xFF8D6B0B),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            onTap: () => onOpenGroup(i),
                          ),
                        ),
                      ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFF8E8) : DesignTokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: emphasize
              ? const Color(0xFFF0B429).withValues(alpha: 0.45)
              : DesignTokens.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: emphasize ? const Color(0xFF8D6B0B) : DesignTokens.inkMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color:
                  emphasize ? const Color(0xFF8D6B0B) : DesignTokens.inkMuted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinCodeBadge extends StatelessWidget {
  const _JoinCodeBadge({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: DesignTokens.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        code,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      SessionStatus.active => (
          'Aktif',
          const Color(0xFFE3F8E8),
          const Color(0xFF0E7A3D),
        ),
      SessionStatus.draft => (
          'Draft',
          const Color(0xFFEFF3F6),
          DesignTokens.inkMuted,
        ),
      SessionStatus.closed => (
          'Ditutup',
          const Color(0xFFF7EAEA),
          const Color(0xFF9B2C2C),
        ),
      SessionStatus.paused => (
          'Dijeda',
          const Color(0xFFFFF8E8),
          const Color(0xFF8D6B0B),
        ),
      SessionStatus.unknown => (
          status.name,
          DesignTokens.border,
          DesignTokens.inkMuted,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
