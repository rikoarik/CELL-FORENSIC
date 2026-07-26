import 'package:cell_forensic/features/investigation/investigation_sync.dart';
import 'package:cell_forensic/features/journey/student_journey.dart';
import 'package:flutter/material.dart';

/// Layar kesimpulan investigasi.
///
/// Mengumpulkan lima field wajib (identitas & alasan untuk Sampel A dan B serta
/// hipotesis akhir) lalu mengirimkannya via
/// [StudentJourney.submitInvestigation]. Draft di-autosave lokal (+ sync
/// jika cloud). Jika ada field yang kosong, guard pada journey menolak dan
/// [StudentJourney.lastError] ditampilkan.
class ConclusionScreen extends StatefulWidget {
  const ConclusionScreen({required this.journey, super.key});

  final StudentJourney journey;

  @override
  State<ConclusionScreen> createState() => _ConclusionScreenState();
}

class _ConclusionScreenState extends State<ConclusionScreen> {
  late final TextEditingController _sampleAIdentity;
  late final TextEditingController _sampleAReasoning;
  late final TextEditingController _sampleBIdentity;
  late final TextEditingController _sampleBReasoning;
  late final TextEditingController _hypothesis;

  @override
  void initState() {
    super.initState();
    final draft = widget.journey.conclusionDraft;
    _sampleAIdentity = TextEditingController(
      text: draft?.sampleAIdentity ?? '',
    );
    _sampleAReasoning = TextEditingController(
      text: draft?.sampleAReasoning ?? '',
    );
    _sampleBIdentity = TextEditingController(
      text: draft?.sampleBIdentity ?? '',
    );
    _sampleBReasoning = TextEditingController(
      text: draft?.sampleBReasoning ?? '',
    );
    _hypothesis = TextEditingController(text: draft?.hypothesis ?? '');
    widget.journey.addListener(_onJourneyChanged);
  }

  void _onJourneyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.journey.removeListener(_onJourneyChanged);
    _sampleAIdentity.dispose();
    _sampleAReasoning.dispose();
    _sampleBIdentity.dispose();
    _sampleBReasoning.dispose();
    _hypothesis.dispose();
    super.dispose();
  }

  void _autosaveDraft() {
    widget.journey.saveConclusionDraft(
      ConclusionDraft(
        sampleAIdentity: _sampleAIdentity.text,
        sampleAReasoning: _sampleAReasoning.text,
        sampleBIdentity: _sampleBIdentity.text,
        sampleBReasoning: _sampleBReasoning.text,
        hypothesis: _hypothesis.text,
      ),
    );
  }

  void _submit() {
    widget.journey.submitInvestigation(
      sampleAIdentity: _sampleAIdentity.text,
      sampleAReasoning: _sampleAReasoning.text,
      sampleBIdentity: _sampleBIdentity.text,
      sampleBReasoning: _sampleBReasoning.text,
      hypothesis: _hypothesis.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = widget.journey.lastError;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Rangkum temuan kelompokmu untuk kedua sampel.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.journey.isCloudSynced
                  ? 'Draft kesimpulan tersimpan otomatis dan diantrekan sync.'
                  : 'Draft kesimpulan tersimpan otomatis secara lokal.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _field(
              key: const Key('conclusion-sample-a-identity'),
              controller: _sampleAIdentity,
              label: 'Identitas Sampel A',
            ),
            _field(
              key: const Key('conclusion-sample-a-reasoning'),
              controller: _sampleAReasoning,
              label: 'Alasan identitas Sampel A',
              multiline: true,
            ),
            _field(
              key: const Key('conclusion-sample-b-identity'),
              controller: _sampleBIdentity,
              label: 'Identitas Sampel B',
            ),
            _field(
              key: const Key('conclusion-sample-b-reasoning'),
              controller: _sampleBReasoning,
              label: 'Alasan identitas Sampel B',
              multiline: true,
            ),
            _field(
              key: const Key('conclusion-hypothesis'),
              controller: _hypothesis,
              label: 'Hipotesis akhir kelompok',
              multiline: true,
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Submit investigasi',
              child: FilledButton(
                key: const Key('conclusion-submit'),
                onPressed: _submit,
                child: const Text('Submit Investigasi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required Key key,
    required TextEditingController controller,
    required String label,
    bool multiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: key,
        controller: controller,
        minLines: multiline ? 2 : 1,
        maxLines: multiline ? 4 : 1,
        onChanged: (_) => _autosaveDraft(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
