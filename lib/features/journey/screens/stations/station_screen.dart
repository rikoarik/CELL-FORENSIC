import 'dart:async';

import 'package:cell_forensic/features/content/local_content_pack.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';

/// Evaluation (POS) station screen for the student journey.
///
/// Before a station is unlocked it offers simulated marker scan (FR-091) with
/// PIN fallback (FR-092). Once unlocked it runs a countdown from
/// [StudentJourney.stationExpiresAt] / [ContentPack.stationDurationSeconds]
/// (FR-093), autosaves answers (FR-094), rotates POS 1→2→3 (FR-095), and locks
/// answers on submit or timeout (FR-096).
class StationScreen extends StatefulWidget {
  const StationScreen({required this.journey, super.key});

  final StudentJourney journey;

  @override
  State<StationScreen> createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen>
    with WidgetsBindingObserver {
  final TextEditingController _pinController = TextEditingController();
  final Map<String, TextEditingController> _answerControllers = {};

  Timer? _timer;
  int _remainingSeconds = 0;
  bool _wasUnlocked = false;
  int _boundStationIndex = -1;

  StudentJourney get _journey => widget.journey;

  bool get _isUnlocked =>
      _journey.stage == JourneyStage.stations && _journey.activeStationUnlocked;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _boundStationIndex = _journey.stationIndex;
    _wasUnlocked = _isUnlocked;
    if (_wasUnlocked) {
      _syncRemainingFromJourney();
      if (_remainingSeconds <= 0) {
        _journey.submitActiveStation(expired: true);
      } else {
        _timer = Timer.periodic(const Duration(seconds: 1), _tick);
      }
    }
    _journey.addListener(_onJourneyChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _journey.removeListener(_onJourneyChanged);
    _stopCountdown();
    _pinController.dispose();
    _disposeAnswerControllers();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isUnlocked) {
      _enforceWallClockExpiry();
    }
  }

  void _onJourneyChanged() {
    if (_journey.stationIndex != _boundStationIndex) {
      _boundStationIndex = _journey.stationIndex;
      _disposeAnswerControllers();
    }

    final unlocked = _isUnlocked;
    if (unlocked && !_wasUnlocked) {
      _wasUnlocked = true;
      _beginCountdown();
    } else if (!unlocked && _wasUnlocked) {
      _wasUnlocked = false;
      _stopCountdown();
    }
  }

  void _disposeAnswerControllers() {
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    _answerControllers.clear();
  }

  void _syncRemainingFromJourney() {
    _remainingSeconds =
        _journey.stationRemainingSeconds ??
        _journey.content.stationDurationSeconds;
  }

  void _beginCountdown() {
    _timer?.cancel();
    setState(_syncRemainingFromJourney);
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  /// Recomputes remaining time from [StudentJourney.stationExpiresAt] so
  /// backgrounding cannot grant extra editing time (FR-093 / FR-096).
  void _enforceWallClockExpiry() {
    if (!mounted || !_isUnlocked) return;
    final remaining = _journey.stationRemainingSeconds;
    if (remaining == null) return;
    if (remaining <= 0) {
      setState(() => _remainingSeconds = 0);
      _stopCountdown();
      if (!_journey.isStationSubmitted(_journey.activeStation.code)) {
        _journey.submitActiveStation(expired: true);
      }
      return;
    }
    setState(() => _remainingSeconds = remaining);
  }

  void _tick(Timer timer) {
    if (!mounted) return;
    // Wall-clock wins when already expired (app was backgrounded). Local
    // decrement still drives widget tests where FakeAsync Timers advance but
    // DateTime.now() may not.
    final wallRemaining = _journey.stationRemainingSeconds;
    if (wallRemaining != null && wallRemaining <= 0) {
      setState(() => _remainingSeconds = 0);
      _stopCountdown();
      _journey.submitActiveStation(expired: true);
      return;
    }
    if (_remainingSeconds <= 1) {
      setState(() => _remainingSeconds = 0);
      _stopCountdown();
      _journey.submitActiveStation(expired: true);
      return;
    }
    setState(() {
      _remainingSeconds--;
      if (wallRemaining != null && wallRemaining < _remainingSeconds) {
        _remainingSeconds = wallRemaining;
      }
    });
  }

  void _stopCountdown() {
    _timer?.cancel();
    _timer = null;
  }

  TextEditingController _answerController(QuestionContent question) {
    return _answerControllers.putIfAbsent(
      question.code,
      () =>
          TextEditingController(text: _journey.answerFor(question.code) ?? ''),
    );
  }

  void _unlockWithPin() {
    _journey.unlockStation(_pinController.text);
    _pinController.clear();
  }

  void _simulateMarker() {
    _journey.simulateMarkerScan();
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _journey,
          builder: (context, _) {
            return _isUnlocked
                ? _buildUnlocked(context)
                : _buildLocked(context);
          },
        ),
      ),
    );
  }

  Widget _buildLocked(BuildContext context) {
    final station = _journey.activeStation;
    final theme = Theme.of(context);
    final error = _journey.lastError;
    final next = _journey.nextStationInRotation;
    final rotationLabel = next == null
        ? 'Stasiun terakhir dalam rotasi POS.'
        : 'Setelah selesai, rotasi ke ${next.title}.';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(station.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Buka ${station.code} dengan memindai marker, atau masukkan PIN '
            'jika pemindaian gagal.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          Text(
            rotationLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Simulasikan pemindaian marker stasiun',
            child: FilledButton.icon(
              key: const ValueKey('station-marker-scan'),
              onPressed: _simulateMarker,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: const Text('Pindai Marker'),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            hint: 'Panduan bila pemindaian marker gagal',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Pemindaian penanda (marker) gagal atau tidak tersedia? '
                'Masukkan PIN stasiun secara manual di bawah ini untuk tetap '
                'melanjutkan.',
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('station-pin'),
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: false,
            decoration: const InputDecoration(
              labelText: 'PIN Stasiun',
              hintText: 'Contoh: 1111',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _unlockWithPin(),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: 'Buka stasiun dengan PIN',
            child: FilledButton.tonal(
              onPressed: _unlockWithPin,
              child: const Text('Buka Stasiun'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnlocked(BuildContext context) {
    final station = _journey.activeStation;
    final theme = Theme.of(context);
    final next = _journey.nextStationInRotation;
    final locked = _journey.isStationSubmitted(station.code);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(station.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            next == null
                ? 'Selesaikan soal, lalu kumpulkan untuk melihat hasil.'
                : 'Selesaikan soal. Setelah dikumpulkan, rotasi ke ${next.code}.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            label: 'Sisa waktu ${_formatTime(_remainingSeconds)}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 12),
                  Text('Sisa waktu', style: theme.textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          for (final question in station.questions) ...[
            _QuestionField(
              question: question,
              controller: _answerController(question),
              readOnly: locked,
              onChanged: (value) =>
                  _journey.answerQuestion(question.code, value),
            ),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 4),
          Semantics(
            button: true,
            label: 'Kumpulkan jawaban stasiun ini',
            child: FilledButton(
              onPressed: locked ? null : () => _journey.submitActiveStation(),
              child: const Text('Kumpulkan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    required this.question,
    required this.controller,
    required this.onChanged,
    this.readOnly = false,
  });

  final QuestionContent question;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEssay = question.kind == QuestionKind.essay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question.text, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: ValueKey('answer-${question.code}'),
          controller: controller,
          onChanged: readOnly ? null : onChanged,
          readOnly: readOnly,
          minLines: isEssay ? 3 : 1,
          maxLines: isEssay ? 6 : 1,
          textInputAction: isEssay
              ? TextInputAction.newline
              : TextInputAction.done,
          decoration: InputDecoration(
            labelText: isEssay ? 'Jawaban esai' : 'Jawaban',
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
