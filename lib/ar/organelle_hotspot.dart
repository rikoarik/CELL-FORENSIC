import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:flutter/foundation.dart';

/// Sample A organelle / cell tap targets (observation only — not mission progress).
enum OrganelleHotspotId {
  /// Whole plant-cell scan popup (M3 damaged-cell entry).
  plantCell,
  chloroplast,
  vacuole,
}

/// Per-hotspot UI state, independent of [MissionProgress] / sequence.
enum OrganelleHotspotPhase {
  /// Not yet tapped this placement session (or cleared on reset scan).
  none,

  /// Currently chosen — outline/glow active, popup may be open.
  selected,

  /// Student opened the observation popup and/or logged a note.
  /// Does **not** mean the mission is completed.
  inspected,
}

/// Copy + action payloads for a Sample A organelle hint.
@immutable
class OrganelleHotspotContent {
  const OrganelleHotspotContent({
    required this.id,
    required this.title,
    required this.body,
    required this.draftAiQuestion,
    required this.logbookPromptSubstring,
    required this.nodeId,
  });

  final OrganelleHotspotId id;
  final String title;
  final String body;

  /// Pre-filled into the assistant input — never auto-sent.
  final String draftAiQuestion;

  /// Matched against mission [logbookPrompts] to focus the related field.
  final String logbookPromptSubstring;

  /// Logical [ArNodeIds] highlight target.
  final String nodeId;

  String get semanticsLabel => switch (id) {
    OrganelleHotspotId.plantCell => 'Ketuk sel tumbuhan rusak',
    OrganelleHotspotId.chloroplast => 'Ketuk kloroplas',
    OrganelleHotspotId.vacuole => 'Ketuk vakuola raksasa',
  };
}

/// Intro tip shown after lab placement (before any organelle tap).
@immutable
class OrganelleIntroHint {
  const OrganelleIntroHint({
    required this.title,
    required this.body,
    required this.instruction,
  });

  final String title;
  final String body;
  final String instruction;
}

/// Catalog for Sample A investigation hotspots (Indonesian UI copy).
///
/// Plant-cell scan copy is the M3 damaged-cell example (sel tumbuhan).
abstract final class SampleAOrganelleHotspots {
  static const intro = OrganelleIntroHint(
    title: 'Petunjuk Investigasi',
    body:
        'Cell tumbuhan mengalami krisis turgor. Analisis cell berikut pada '
        'bagian mana yang rusak.',
    instruction: 'Ketuk sel atau organel yang ingin diperiksa.',
  );

  /// Whole-cell scan result (contoh: sel tumbuhan rusak / Sampel A).
  /// Popup terbuka saat siswa ketuk sel di TempatUji A — 3D tetap di scene.
  static const plantCell = OrganelleHotspotContent(
    id: OrganelleHotspotId.plantCell,
    title: 'Hasil Pemindaian — Sel Tumbuhan',
    body:
        'Hasil pemindaian menunjukkan cell tumbuhan ini mengalami kerusakan '
        'parah pada Kloroplas dan Vakuola Raksasa. Kloroplas berperan dalam '
        'fotosintesis untuk menghasilkan glukosa/energi, sementara Vakuola '
        'raksasa menjaga turgiditas (kekerasan) sel. Coba analisis, apa '
        'dampaknya bagi energi dan tekanan internal sel jika kedua organel '
        'tersebut tidak berfungsi?',
    draftAiQuestion:
        'Apa dampaknya bagi energi dan tekanan internal sel jika kloroplas '
        'dan vakuola raksasa tidak berfungsi?',
    logbookPromptSubstring: 'Organel yang tampak rusak',
    nodeId: ArNodeIds.sampleA,
  );

  static const chloroplast = OrganelleHotspotContent(
    id: OrganelleHotspotId.chloroplast,
    title: 'Kloroplas',
    body:
        'Struktur ini tampak menyusut dan kehilangan warna. Menurutmu, '
        'bagaimana kerusakan ini memengaruhi kemampuan sel menghasilkan energi?',
    draftAiQuestion:
        'Bagaimana kerusakan kloroplas memengaruhi kemampuan sel '
        'menghasilkan energi?',
    logbookPromptSubstring: 'Organel yang tampak rusak',
    nodeId: ArNodeIds.chloroplast,
  );

  static const vacuole = OrganelleHotspotContent(
    id: OrganelleHotspotId.vacuole,
    title: 'Vakuola Raksasa',
    body:
        'Ukuran vakuola tampak mengecil. Apa pengaruhnya terhadap tekanan '
        'turgor dan bentuk sel?',
    draftAiQuestion:
        'Apa pengaruh mengecilnya vakuola terhadap tekanan turgor '
        'dan bentuk sel?',
    logbookPromptSubstring: 'Bentuk/gejala klinis',
    nodeId: ArNodeIds.vacuole,
  );

  static const List<OrganelleHotspotContent> all = [
    plantCell,
    chloroplast,
    vacuole,
  ];

  static OrganelleHotspotContent contentFor(OrganelleHotspotId id) =>
      switch (id) {
        OrganelleHotspotId.plantCell => plantCell,
        OrganelleHotspotId.chloroplast => chloroplast,
        OrganelleHotspotId.vacuole => vacuole,
      };

  static OrganelleHotspotId? tryParse(String raw) {
    for (final id in OrganelleHotspotId.values) {
      if (id.name == raw) return id;
    }
    return null;
  }
}

/// Tracks Sample A hotspot selection / inspection without touching missions.
class OrganelleHotspotController extends ChangeNotifier {
  OrganelleHotspotController({
    Set<OrganelleHotspotId>? initiallyInspected,
  }) : _inspected = {...?initiallyInspected};

  final Set<OrganelleHotspotId> _inspected;
  OrganelleHotspotId? _selected;
  OrganelleHotspotId? _openPopup;
  bool _introDismissed = false;
  bool _enabled = false;

  /// Hotspots only exist after group + lab placement.
  bool get enabled => _enabled;

  OrganelleHotspotId? get selectedId => _selected;

  OrganelleHotspotId? get openPopupId => _openPopup;

  bool get introVisible => _enabled && !_introDismissed && _openPopup == null;

  Set<OrganelleHotspotId> get inspectedIds => Set.unmodifiable(_inspected);

  OrganelleHotspotPhase phaseOf(OrganelleHotspotId id) {
    if (!_enabled) return OrganelleHotspotPhase.none;
    if (_selected == id) return OrganelleHotspotPhase.selected;
    if (_inspected.contains(id)) return OrganelleHotspotPhase.inspected;
    return OrganelleHotspotPhase.none;
  }

  /// Gate interaction until Scene 1 placement (or Mode 3D ready).
  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    if (!value) {
      _selected = null;
      _openPopup = null;
    }
    notifyListeners();
  }

  /// Restore inspected set from snapshot (no orphan before enable).
  void restoreInspected(Iterable<OrganelleHotspotId> ids) {
    _inspected
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Tap organelle/cell: select + open observation popup. Never completes a
  /// mission and never emits `sequenceCode`.
  void select(OrganelleHotspotId id) {
    if (!_enabled) return;
    _selected = id;
    _openPopup = id;
    _introDismissed = true;
    notifyListeners();
  }

  /// Close popup → mark [inspected]. Selection highlight clears by default.
  /// Inspected ≠ mission completed.
  void closePopup({bool clearSelection = true}) {
    if (_openPopup == null && _selected == null) return;
    final opened = _openPopup ?? _selected;
    if (opened != null) {
      _inspected.add(opened);
    }
    _openPopup = null;
    if (clearSelection) {
      _selected = null;
    }
    notifyListeners();
  }

  /// Observation logged (e.g. Catat di Logbook) without requiring Tutup.
  void markInspected(OrganelleHotspotId id) {
    if (!_enabled) return;
    _inspected.add(id);
    if (_openPopup == id) _openPopup = null;
    if (_selected == id) _selected = null;
    notifyListeners();
  }

  void dismissIntro() {
    if (_introDismissed) return;
    _introDismissed = true;
    notifyListeners();
  }

  /// Reset scan: clear selected / open popup. Inspected may persist.
  void clearSelection() {
    if (_selected == null && _openPopup == null) return;
    _selected = null;
    _openPopup = null;
    notifyListeners();
  }

  /// Full placement teardown — also clears selection; inspected stays unless
  /// [clearInspected] is true.
  void onResetScan({bool clearInspected = false}) {
    _selected = null;
    _openPopup = null;
    _introDismissed = false;
    _enabled = false;
    if (clearInspected) {
      _inspected.clear();
    }
    notifyListeners();
  }
}
