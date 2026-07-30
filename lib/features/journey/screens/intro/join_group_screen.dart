import 'package:cell_forensic/domain/entities.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:cell_forensic/features/session/persisted_session_repository.dart';
import 'package:cell_forensic/features/session/remote_session_service.dart';
import 'package:cell_forensic/features/session/session_repository.dart';
import 'package:cell_forensic/features/session/session_snapshot_store.dart';
import 'package:flutter/material.dart';

/// Student join + group setup surface for E2.
///
/// Steps:
/// 1. [JourneyStage.joinSession] — enter join code (local CELL01 and/or remote)
/// 2. [JourneyStage.groupSetup] — create group, add members, promote leader
///
/// Offline-first: repository writes succeed locally; remote registration is
/// best-effort and never blocks continuing.
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({
    required this.journey,
    required this.sessionRepository,
    this.remoteSessionService = const RemoteSessionService(),
    this.snapshotStore,
    super.key,
  });

  final StudentJourney journey;
  final SessionRepository sessionRepository;
  final RemoteSessionService remoteSessionService;
  final SessionSnapshotStore? snapshotStore;

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final _joinCodeController = TextEditingController();
  final _groupController = TextEditingController();
  final _leaderController = TextEditingController();
  final _memberController = TextEditingController();
  bool _busy = false;

  StudentJourney get _journey => widget.journey;
  SessionRepository get _repo => widget.sessionRepository;

  @override
  void initState() {
    super.initState();
    _joinCodeController.text = _journey.joinCode ?? '';
    final existing = _journey.group;
    if (existing != null) {
      _groupController.text = existing.name;
      _leaderController.text = _journey.leaderName ?? '';
    }
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    _groupController.dispose();
    _leaderController.dispose();
    _memberController.dispose();
    super.dispose();
  }

  void _persistSnapshot() {
    final store = widget.snapshotStore;
    final snap = _journey.toSessionSnapshot();
    if (store == null || snap == null) return;
    store.save(snap);
  }

  Future<void> _joinByCode() async {
    if (_busy) return;
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _journey.reportError('Kode gabung tidak valid.');
      return;
    }

    setState(() => _busy = true);
    try {
      LearningSession? session;
      final local = await _repo.joinSession(code);
      if (local case Ok(:final value)) {
        session = value;
      } else {
        final remote = await widget.remoteSessionService.findActiveSession(
          code,
        );
        if (remote != null) {
          session = remote;
          final repo = _repo;
          if (repo is PersistedSessionRepository) {
            repo.upsertSession(remote);
          }
        }
      }

      if (!mounted) return;
      if (session == null) {
        _journey.reportError(SessionError.invalidJoinCode.message);
        return;
      }

      _journey.acceptJoinedSession(
        joinCode: session.joinCode,
        sessionId: session.id,
        sessionTitle: session.title.isEmpty
            ? _journey.content.sessionTitle
            : session.title,
      );
      _persistSnapshot();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createGroup() async {
    if (_busy) return;
    final sessionId = _journey.sessionId;
    if (sessionId == null) {
      _journey.reportError('Gabung sesi terlebih dahulu.');
      return;
    }

    final name = _groupController.text.trim();
    final leader = _leaderController.text.trim();
    if (name.isEmpty || leader.isEmpty) {
      _journey.reportError('Nama kelompok dan ketua wajib diisi.');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _repo.createGroup(
        sessionId: sessionId,
        name: name,
        leaderName: leader,
      );
      if (!mounted) return;

      switch (result) {
        case Ok(:final value):
          final remote = await widget.remoteSessionService.joinActiveSession(
            joinCode: _journey.joinCode ?? _journey.content.joinCode,
            groupName: name,
            leaderName: leader,
          );
          if (!mounted) return;
          _journey.setGroup(
            value,
            remoteSessionId: remote?.sessionId,
            remoteGroupId: remote?.groupId,
          );
          _persistSnapshot();
        case Err(:final error):
          _journey.reportError(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addMember() async {
    final group = _journey.group;
    if (group == null || _busy) return;
    final name = _memberController.text.trim();
    if (name.isEmpty) {
      _journey.reportError(SessionError.emptyMemberName.message);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _repo.addMember(
        groupId: group.id,
        displayName: name,
      );
      if (!mounted) return;
      switch (result) {
        case Ok(:final value):
          _memberController.clear();
          _journey.setGroup(value);
          _persistSnapshot();
        case Err(:final error):
          _journey.reportError(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _promote(GroupMember member) async {
    final group = _journey.group;
    if (group == null || _busy || member.isLeader) return;

    setState(() => _busy = true);
    try {
      final result = await _repo.promoteMember(
        groupId: group.id,
        memberId: member.id,
      );
      if (!mounted) return;
      switch (result) {
        case Ok(:final value):
          _journey.setGroup(value);
          _persistSnapshot();
        case Err(:final error):
          _journey.reportError(error.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueToScene1() {
    // PDF Scene 1: after group is ready → AR init (skip mandatory onboarding).
    // Does not auto-start Misi 1 — progress stays empty until placement/intent.
    _journey.confirmGroupReady();
    if (_journey.stage == JourneyStage.investigating) {
      _persistSnapshot();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _journey,
      builder: (context, _) {
        return switch (_journey.stage) {
          JourneyStage.joinSession => _JoinCodeStep(
            controller: _joinCodeController,
            journey: _journey,
            busy: _busy,
            onJoin: _joinByCode,
          ),
          JourneyStage.groupSetup => _GroupSetupStep(
            journey: _journey,
            groupController: _groupController,
            leaderController: _leaderController,
            memberController: _memberController,
            busy: _busy,
            onCreateGroup: _createGroup,
            onAddMember: _addMember,
            onPromote: _promote,
            onContinue: _continueToScene1,
          ),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _JoinCodeStep extends StatelessWidget {
  const _JoinCodeStep({
    required this.controller,
    required this.journey,
    required this.busy,
    required this.onJoin,
  });

  final TextEditingController controller;
  final StudentJourney journey;
  final bool busy;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = journey.lastError;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Gabung Sesi', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                journey.sessionTitle ?? journey.content.sessionTitle,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text('Kode Sesi', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              TextField(
                key: const Key('joinCodeField'),
                controller: controller,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onJoin(),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Contoh: CELL01',
                  labelText: 'Kode gabung',
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                _ErrorBanner(message: error),
              ],
              const SizedBox(height: 28),
              Semantics(
                button: true,
                label: 'Gabung ke sesi praktikum',
                child: FilledButton(
                  key: const Key('joinSessionButton'),
                  onPressed: busy ? null : onJoin,
                  child: Text(busy ? 'Memeriksa…' : 'Gabung'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSetupStep extends StatelessWidget {
  const _GroupSetupStep({
    required this.journey,
    required this.groupController,
    required this.leaderController,
    required this.memberController,
    required this.busy,
    required this.onCreateGroup,
    required this.onAddMember,
    required this.onPromote,
    required this.onContinue,
  });

  final StudentJourney journey;
  final TextEditingController groupController;
  final TextEditingController leaderController;
  final TextEditingController memberController;
  final bool busy;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddMember;
  final void Function(GroupMember member) onPromote;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = journey.lastError;
    final group = journey.group;
    final hasGroup = group != null;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Buat Kelompok', style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                'Sesi ${journey.joinCode ?? journey.content.joinCode}',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              if (!hasGroup) ...[
                Text('Nama Kelompok', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('joinGroupNameField'),
                  controller: groupController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Contoh: Kelompok Mawar',
                    labelText: 'Nama kelompok',
                  ),
                ),
                const SizedBox(height: 20),
                Text('Nama Ketua Kelompok', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('joinLeaderNameField'),
                  controller: leaderController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onCreateGroup(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Contoh: Ani',
                    labelText: 'Nama ketua',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: error),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('createGroupButton'),
                  onPressed: busy ? null : onCreateGroup,
                  child: Text(busy ? 'Menyimpan…' : 'Buat Kelompok'),
                ),
              ] else ...[
                _GroupSummaryCard(group: group),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('changeGroupButton'),
                  onPressed: busy
                      ? null
                      : () {
                          groupController.clear();
                          leaderController.clear();
                          memberController.clear();
                          journey.clearGroup();
                        },
                  child: const Text('Buat Kelompok Baru'),
                ),
                const SizedBox(height: 20),
                Text('Anggota Kelompok', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final member in group.members)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      member.isLeader
                          ? Icons.star_rounded
                          : Icons.person_outline_rounded,
                      color: member.isLeader
                          ? theme.colorScheme.secondary
                          : null,
                    ),
                    title: Text(member.displayName),
                    subtitle: Text(member.isLeader ? 'Ketua' : 'Anggota'),
                    trailing: member.isLeader
                        ? null
                        : TextButton(
                            key: Key('promote_${member.id}'),
                            onPressed: busy ? null : () => onPromote(member),
                            child: const Text('Jadikan Ketua'),
                          ),
                  ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('addMemberField'),
                  controller: memberController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onAddMember(),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Nama anggota baru',
                    labelText: 'Tambah anggota',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('addMemberButton'),
                  onPressed: busy ? null : onAddMember,
                  child: const Text('Tambah Anggota'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: error),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  key: const Key('continueOnboardingButton'),
                  onPressed: busy ? null : onContinue,
                  child: const Text('Masuk Laboratorium AR'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupSummaryCard extends StatelessWidget {
  const _GroupSummaryCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leader = group.members
        .where((m) => m.isLeader)
        .map((m) => m.displayName)
        .join();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(group.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Ketua: $leader · ${group.members.length} anggota',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
