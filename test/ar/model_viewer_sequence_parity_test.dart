import 'package:cell_forensic/ar/ar_scene_engine.dart';
import 'package:cell_forensic/ar/mission_scene_panel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const visual = ArSceneVisualState();

  test('Misi 1 focuses Sample A and progressively zooms organelles', () {
    final focus = fallbackCameraPoseFor(
      missionCode: 'MISI-1',
      stepCode: 'focus_sample_a',
      visual: visual,
    );
    final internal = fallbackCameraPoseFor(
      missionCode: 'MISI-1',
      stepCode: 'zoom_internal',
      visual: visual,
    );

    expect(focus.slide.dx, greaterThan(0));
    expect(internal.slide.dx, greaterThan(0));
    expect(internal.scale, greaterThan(focus.scale));
  });

  test('Misi 2 focuses Sample B and zooms into its membrane', () {
    final focus = fallbackCameraPoseFor(
      missionCode: 'MISI-2',
      stepCode: 'focus_sample_b',
      visual: visual,
    );
    final membrane = fallbackCameraPoseFor(
      missionCode: 'MISI-2',
      stepCode: 'zoom_membrane',
      visual: visual,
    );
    final torn = fallbackCameraPoseFor(
      missionCode: 'MISI-2',
      stepCode: 'show_torn_bilayer',
      visual: visual,
    );

    expect(focus.slide.dx, lessThan(0));
    expect(membrane.slide.dx, lessThan(0));
    expect(membrane.scale, greaterThan(focus.scale));
    expect(torn.scale, greaterThan(membrane.scale));
  });

  test('Misi 3 alternates Sample A, comparison, and Sample B focus', () {
    final sampleA = fallbackCameraPoseFor(
      missionCode: 'MISI-3',
      stepCode: 'show_damaged_sample_a',
      visual: visual,
    );
    final both = fallbackCameraPoseFor(
      missionCode: 'MISI-3',
      stepCode: 'show_both_samples',
      visual: visual,
    );
    final sampleB = fallbackCameraPoseFor(
      missionCode: 'MISI-3',
      stepCode: 'mark_sample_b',
      visual: visual,
    );

    expect(sampleA.slide.dx, greaterThan(0));
    expect(both.slide.dx, 0);
    expect(sampleB.slide.dx, lessThan(0));
  });

  test('engine zoom factor is honored by fallback camera', () {
    const zoomed = ArSceneVisualState(zoomFactor: 1.8, userScale: 1.1);
    final pose = fallbackCameraPoseFor(
      missionCode: 'MISI-2',
      stepCode: 'zoom_membrane',
      visual: zoomed,
    );

    expect(pose.scale, closeTo(1.98, 0.001));
  });
}
