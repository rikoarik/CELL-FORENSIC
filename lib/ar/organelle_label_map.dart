/// Validated UI labels for organelles / membrane regions (E0-08).
///
/// Biology placeholders "Organel X/Y" and membrane parts "1/2" stay *unassigned*
/// until a node with a stable semantic name exists in the GLB (see
/// `docs/09_LKPD_EVALUATION_SCORING.md`). This map only exposes labels that are
/// backed by real asset nodes or dedicated solo GLBs.
class OrganelleLabel {
  const OrganelleLabel({
    required this.code,
    required this.displayId,
    required this.nodeOrAsset,
    required this.sampleRef,
    required this.validated,
    this.note = '',
  });

  /// Stable machine code (e.g. `A_CELL_WALL`).
  final String code;

  /// Student-facing Indonesian label.
  final String displayId;

  /// GLB node name **or** solo asset path used to show this structure.
  final String nodeOrAsset;

  /// `SAMPLE_A` | `SAMPLE_B` | `LAB`
  final String sampleRef;

  /// True when a semantic node/file exists; false = still provisional.
  final bool validated;

  final String note;
}

class OrganelleLabelMap {
  const OrganelleLabelMap._();

  static const labels = <OrganelleLabel>[
    // —— Sampel A (tumbuhan) — semantic nodes / solo assets exist ——
    OrganelleLabel(
      code: 'A_CELL_WALL',
      displayId: 'Dinding sel',
      nodeOrAsset: 'DindingSel',
      sampleRef: 'SAMPLE_A',
      validated: true,
    ),
    OrganelleLabel(
      code: 'A_VACUOLE_MAIN',
      displayId: 'Vakuola utama',
      nodeOrAsset: 'Vakuola Main',
      sampleRef: 'SAMPLE_A',
      validated: true,
    ),
    OrganelleLabel(
      code: 'A_NUCLEUS',
      displayId: 'Nukleus',
      nodeOrAsset:
          'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/Nukleus_Solo.glb',
      sampleRef: 'SAMPLE_A',
      validated: true,
      note: 'Ditampilkan via solo GLB (node di AllInOne masih Sphere.*).',
    ),
    OrganelleLabel(
      code: 'A_CHLOROPLAST',
      displayId: 'Kloroplas',
      nodeOrAsset:
          'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/KlooroPlas_Solo.glb',
      sampleRef: 'SAMPLE_A',
      validated: true,
      note: 'Ditampilkan via solo GLB.',
    ),
    OrganelleLabel(
      code: 'A_MITOCHONDRION',
      displayId: 'Mitokondria',
      nodeOrAsset:
          'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/Mitokondria_Solo.glb',
      sampleRef: 'SAMPLE_A',
      validated: true,
    ),
    OrganelleLabel(
      code: 'A_CYTOPLASM',
      displayId: 'Sitoplasma',
      nodeOrAsset:
          'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/Sitoplasma_Solo.glb',
      sampleRef: 'SAMPLE_A',
      validated: true,
    ),
    OrganelleLabel(
      code: 'A_VACUOLE_SMALL',
      displayId: 'Vakuola kecil',
      nodeOrAsset:
          'assets/ar_models/SelTumbuhan/SelTumbuhhanSolo/VakolaKecil_Solo.glb',
      sampleRef: 'SAMPLE_A',
      validated: true,
    ),

    // —— Provisional Organel X / Y (NOT assigned — E0-08 / LKPD rule) ——
    OrganelleLabel(
      code: 'ORGANELLE_X',
      displayId: 'Organel X',
      nodeOrAsset: '',
      sampleRef: 'SAMPLE_A',
      validated: false,
      note: 'Belum dipetakan ke node/file — jangan hardcode di soal otomatis.',
    ),
    OrganelleLabel(
      code: 'ORGANELLE_Y',
      displayId: 'Organel Y',
      nodeOrAsset: '',
      sampleRef: 'SAMPLE_A',
      validated: false,
      note: 'Belum dipetakan ke node/file — jangan hardcode di soal otomatis.',
    ),

    // —— Sampel B (hewan / membran) ——
    OrganelleLabel(
      code: 'B_CELL_BODY',
      displayId: 'Sel hewan (rusak)',
      nodeOrAsset: 'assets/ar_models/SelHewan/SelHewanBroken.glb',
      sampleRef: 'SAMPLE_B',
      validated: true,
      note: 'Node internal masih Cube/Plane — highlight per-region belum stabil.',
    ),
    OrganelleLabel(
      code: 'B_PROTEIN_CHAIN',
      displayId: 'Rantai protein / lapisan membran',
      nodeOrAsset: 'assets/ar_models/SelHewan/RantaiProtein/RantaiProtein.glb',
      sampleRef: 'SAMPLE_B',
      validated: true,
      note: 'Proxy visual untuk bilayer/kebocoran sampai node membran bernama ada.',
    ),
    OrganelleLabel(
      code: 'B_MEMBRANE_PART_1',
      displayId: 'Bagian membran 1',
      nodeOrAsset: '',
      sampleRef: 'SAMPLE_B',
      validated: false,
      note: 'Tidak ada node bernomor di GLB — soal POS harus tetap generik.',
    ),
    OrganelleLabel(
      code: 'B_MEMBRANE_PART_2',
      displayId: 'Bagian membran 2',
      nodeOrAsset: '',
      sampleRef: 'SAMPLE_B',
      validated: false,
      note: 'Tidak ada node bernomor di GLB — soal POS harus tetap generik.',
    ),

    // —— Lab ——
    OrganelleLabel(
      code: 'LAB_TABLE',
      displayId: 'Meja laboratorium',
      nodeOrAsset: 'assets/ar_models/Meja/MejaLab.glb',
      sampleRef: 'LAB',
      validated: true,
    ),
    OrganelleLabel(
      code: 'LAB_TEST_STAND',
      displayId: 'Tempat uji',
      nodeOrAsset: 'assets/ar_models/Meja/TempatUji.glb',
      sampleRef: 'LAB',
      validated: true,
    ),
  ];

  static List<OrganelleLabel> get validated =>
      labels.where((l) => l.validated).toList();

  static List<OrganelleLabel> get provisional =>
      labels.where((l) => !l.validated).toList();

  /// Returns false if any code that must stay provisional was incorrectly validated.
  static bool assertProvisionalRules() {
    const mustStayOpen = {
      'ORGANELLE_X',
      'ORGANELLE_Y',
      'B_MEMBRANE_PART_1',
      'B_MEMBRANE_PART_2',
    };
    for (final label in labels) {
      if (mustStayOpen.contains(label.code) && label.validated) return false;
    }
    return true;
  }
}
