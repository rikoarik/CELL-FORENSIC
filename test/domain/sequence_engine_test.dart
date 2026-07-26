import 'package:cell_forensic/domain/sequence_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = SequenceConfig(
    code: 'zoom_chloroplast_vacuole',
    steps: [
      SequenceStep(code: 'zoom'),
      SequenceStep(code: 'glow'),
    ],
  );

  test('memajukan state secara murni mengikuti langkah konfigurasi', () {
    const engine = SequenceEngine();
    var state = engine.start(config);

    expect(state.status, SequenceStatus.running);
    expect(state.currentStep?.code, 'zoom');

    state = engine.completeCurrentStep(state);
    expect(state.status, SequenceStatus.running);
    expect(state.currentStep?.code, 'glow');

    state = engine.completeCurrentStep(state);
    expect(state.status, SequenceStatus.completed);
    expect(state.completionEventCount, 1);
  });

  test('tidak menerbitkan completion kedua untuk sequence selesai', () {
    const engine = SequenceEngine();
    var state = engine.start(config);
    state = engine.completeCurrentStep(state);
    state = engine.completeCurrentStep(state);

    final repeated = engine.completeCurrentStep(state);

    expect(repeated, same(state));
    expect(repeated.completionEventCount, 1);
  });

  test('konfigurasi tanpa langkah langsung selesai satu kali', () {
    const engine = SequenceEngine();
    final state = engine.start(const SequenceConfig(code: 'empty', steps: []));

    expect(state.status, SequenceStatus.completed);
    expect(state.currentStep, isNull);
    expect(state.completionEventCount, 1);
  });

  test('startForSequenceCode memetakan SEQ-MISI-N ke skrip PDF M1/M2/M3', () {
    const engine = SequenceEngine();

    final m1 = engine.startForSequenceCode('SEQ-MISI-1');
    expect(m1, isNotNull);
    expect(
      m1!.config.steps.map((s) => s.code).toList(),
      [
        SequenceStepCodes.focusSampleA,
        SequenceStepCodes.zoomInternal,
        SequenceStepCodes.glowOrganelles,
        SequenceStepCodes.playShrinkAnimation,
      ],
    );

    final m2 = engine.startForSequenceCode('misi-2');
    expect(m2?.config.code, 'SEQ-MISI-2');
    expect(
      m2!.config.steps.map((s) => s.code).toList(),
      [
        SequenceStepCodes.focusSampleB,
        SequenceStepCodes.zoomMembrane,
        SequenceStepCodes.showTornBilayer,
        SequenceStepCodes.playLeakParticles,
      ],
    );

    final m3 = engine.startSequence(3);
    expect(m3?.config.code, 'SEQ-MISI-3');
    expect(
      m3!.config.steps.map((s) => s.code).toList(),
      [
        SequenceStepCodes.showDamagedSampleA,
        SequenceStepCodes.showBothSamples,
        SequenceStepCodes.highlightCellWall,
        SequenceStepCodes.markSampleB,
        SequenceStepCodes.showForceArrows,
      ],
    );

    expect(engine.startForSequenceCode('unknown'), isNull);
  });
}
