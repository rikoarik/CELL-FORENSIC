import 'package:cell_forensic/ar/organelle_hotspot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrganelleHotspotController', () {
    test('no state before placement (disabled)', () {
      final c = OrganelleHotspotController();
      expect(c.enabled, isFalse);
      expect(c.phaseOf(OrganelleHotspotId.chloroplast), OrganelleHotspotPhase.none);
      c.select(OrganelleHotspotId.chloroplast);
      expect(c.selectedId, isNull);
      expect(c.openPopupId, isNull);
      expect(c.inspectedIds, isEmpty);
    });

    test('tap → selected + popup open', () {
      final c = OrganelleHotspotController()..setEnabled(true);
      c.select(OrganelleHotspotId.chloroplast);
      expect(c.selectedId, OrganelleHotspotId.chloroplast);
      expect(c.openPopupId, OrganelleHotspotId.chloroplast);
      expect(
        c.phaseOf(OrganelleHotspotId.chloroplast),
        OrganelleHotspotPhase.selected,
      );
      expect(c.inspectedIds, isEmpty);
    });

    test('close popup → inspected (not mission complete)', () {
      final c = OrganelleHotspotController()..setEnabled(true);
      c.select(OrganelleHotspotId.vacuole);
      c.closePopup();
      expect(c.openPopupId, isNull);
      expect(c.selectedId, isNull);
      expect(
        c.phaseOf(OrganelleHotspotId.vacuole),
        OrganelleHotspotPhase.inspected,
      );
      expect(c.inspectedIds, contains(OrganelleHotspotId.vacuole));
    });

    test('reset scan clears selected; inspected may persist', () {
      final c = OrganelleHotspotController()..setEnabled(true);
      c.select(OrganelleHotspotId.chloroplast);
      c.closePopup();
      c.select(OrganelleHotspotId.vacuole);
      c.onResetScan();
      expect(c.enabled, isFalse);
      expect(c.selectedId, isNull);
      expect(c.openPopupId, isNull);
      expect(c.inspectedIds, contains(OrganelleHotspotId.chloroplast));
      expect(
        c.phaseOf(OrganelleHotspotId.chloroplast),
        OrganelleHotspotPhase.none,
      );
    });

    test('catalog drafts are observation-only (no sequence codes)', () {
      for (final item in SampleAOrganelleHotspots.all) {
        expect(item.draftAiQuestion, isNotEmpty);
        expect(item.draftAiQuestion.toLowerCase(), isNot(contains('seq-misi')));
        expect(item.nodeId, isNotEmpty);
      }
      expect(SampleAOrganelleHotspots.intro.title, 'Petunjuk Investigasi');
      expect(
        SampleAOrganelleHotspots.intro.body.toLowerCase(),
        contains('krisis turgor'),
      );
      expect(
        SampleAOrganelleHotspots.plantCell.body,
        contains('Kloroplas dan Vakuola Raksasa'),
      );
    });

    test('plant cell tap opens scan popup', () {
      final c = OrganelleHotspotController()..setEnabled(true);
      c.select(OrganelleHotspotId.plantCell);
      expect(c.openPopupId, OrganelleHotspotId.plantCell);
      expect(
        SampleAOrganelleHotspots.contentFor(OrganelleHotspotId.plantCell).title,
        contains('Pemindaian'),
      );
    });
  });
}
