/// The naturalization process, from deciding whether you qualify to the oath.
///
/// Authored once in `data/naturalization_guide.json`, bundled with the app so
/// it reads with no network, and served by the backend from the same file — so
/// the app and the website cannot tell an applicant different things.
class NaturalizationGuide {
  const NaturalizationGuide({
    required this.reviewedOn,
    required this.disclaimer,
    required this.timeline,
    required this.steps,
    required this.afterOath,
    required this.applying,
    required this.costs,
    required this.tests,
    required this.sources,
  });

  /// When a human last checked this against uscis.gov. Shown to the user,
  /// and used to decide whether the server's copy is fresher than the bundle.
  final DateTime reviewedOn;
  final String disclaimer;
  final GuideTimeline timeline;
  final List<GuideStep> steps;
  final List<String> afterOath;
  final GuideApplying applying;
  final GuideCosts costs;
  final GuideTests tests;
  final List<GuideLink> sources;

  GuideStep? stepByKey(String key) {
    for (final step in steps) {
      if (step.key == key) return step;
    }
    return null;
  }

  factory NaturalizationGuide.fromJson(Map<String, dynamic> json) {
    return NaturalizationGuide(
      reviewedOn:
          DateTime.tryParse((json['reviewedOn'] ?? '').toString()) ??
          DateTime(1970),
      disclaimer: (json['disclaimer'] ?? '').toString(),
      timeline: GuideTimeline.fromJson(_map(json['timeline'])),
      steps: [
        for (final s in _list(json['steps'])) GuideStep.fromJson(_map(s)),
      ],
      afterOath: _strings(json['afterOath']),
      applying: GuideApplying.fromJson(_map(json['applying'])),
      costs: GuideCosts.fromJson(_map(json['costs'])),
      tests: GuideTests.fromJson(_map(json['tests'])),
      sources: [
        for (final s in _list(json['sources'])) GuideLink.fromJson(_map(s)),
      ],
    );
  }
}

class GuideTimeline {
  const GuideTimeline({
    required this.medianMonths,
    required this.typicalLowMonths,
    required this.typicalHighMonths,
    required this.summary,
    required this.note,
  });

  final int medianMonths;
  final int typicalLowMonths;
  final int typicalHighMonths;
  final String summary;
  final String note;

  factory GuideTimeline.fromJson(Map<String, dynamic> json) => GuideTimeline(
    medianMonths: _int(json['medianMonths']),
    typicalLowMonths: _int(json['typicalLowMonths']),
    typicalHighMonths: _int(json['typicalHighMonths']),
    summary: (json['summary'] ?? '').toString(),
    note: (json['note'] ?? '').toString(),
  );
}

class GuideStep {
  const GuideStep({
    required this.key,
    required this.title,
    required this.timing,
    required this.timingDetail,
    required this.summary,
    required this.details,
  });

  final String key;
  final String title;

  /// When this happens, e.g. "Typically 3–8 weeks after filing".
  final String timing;
  final String timingDetail;
  final String summary;
  final List<String> details;

  factory GuideStep.fromJson(Map<String, dynamic> json) => GuideStep(
    key: (json['key'] ?? '').toString(),
    title: (json['title'] ?? '').toString(),
    timing: (json['timing'] ?? '').toString(),
    timingDetail: (json['timingDetail'] ?? '').toString(),
    summary: (json['summary'] ?? '').toString(),
    details: _strings(json['details']),
  );
}

class GuideApplying {
  const GuideApplying({required this.methods, required this.checklist});

  final List<GuideApplyMethod> methods;
  final List<String> checklist;

  factory GuideApplying.fromJson(Map<String, dynamic> json) => GuideApplying(
    methods: [
      for (final m in _list(json['methods']))
        GuideApplyMethod.fromJson(_map(m)),
    ],
    checklist: _strings(json['checklist']),
  );
}

class GuideApplyMethod {
  const GuideApplyMethod({
    required this.name,
    required this.fee,
    required this.summary,
    required this.points,
  });

  final String name;
  final String fee;
  final String summary;
  final List<String> points;

  factory GuideApplyMethod.fromJson(Map<String, dynamic> json) =>
      GuideApplyMethod(
        name: (json['name'] ?? '').toString(),
        fee: (json['fee'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        points: _strings(json['points']),
      );
}

class GuideCosts {
  const GuideCosts({
    required this.items,
    required this.notes,
    this.proposedChange,
  });

  final List<GuideCostItem> items;
  final List<String> notes;

  /// A fee change that has been proposed but is not in effect. Always shown as
  /// such — an applicant budgeting for the wrong number is a real harm.
  final GuideProposedChange? proposedChange;

  factory GuideCosts.fromJson(Map<String, dynamic> json) {
    final proposed = json['proposedChange'];
    return GuideCosts(
      items: [
        for (final c in _list(json['items'])) GuideCostItem.fromJson(_map(c)),
      ],
      notes: _strings(json['notes']),
      proposedChange: proposed is Map<String, dynamic>
          ? GuideProposedChange.fromJson(proposed)
          : null,
    );
  }
}

class GuideCostItem {
  const GuideCostItem({
    required this.label,
    required this.amount,
    required this.when,
    this.note,
  });

  final String label;
  final String amount;
  final String when;
  final String? note;

  factory GuideCostItem.fromJson(Map<String, dynamic> json) => GuideCostItem(
    label: (json['label'] ?? '').toString(),
    amount: (json['amount'] ?? '').toString(),
    when: (json['when'] ?? '').toString(),
    note: json['note'] as String?,
  );
}

class GuideProposedChange {
  const GuideProposedChange({
    required this.status,
    required this.summary,
    required this.impact,
    this.url,
  });

  final String status;
  final String summary;
  final String impact;
  final String? url;

  factory GuideProposedChange.fromJson(Map<String, dynamic> json) =>
      GuideProposedChange(
        status: (json['status'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        impact: (json['impact'] ?? '').toString(),
        url: json['url'] as String?,
      );
}

class GuideTests {
  const GuideTests({
    required this.english,
    required this.civics,
    required this.exemptions,
    required this.retake,
  });

  final GuideEnglishTest english;
  final GuideCivicsTest civics;
  final List<GuideExemption> exemptions;
  final String retake;

  factory GuideTests.fromJson(Map<String, dynamic> json) => GuideTests(
    english: GuideEnglishTest.fromJson(_map(json['english'])),
    civics: GuideCivicsTest.fromJson(_map(json['civics'])),
    exemptions: [
      for (final e in _list(json['exemptions']))
        GuideExemption.fromJson(_map(e)),
    ],
    retake: (json['retake'] ?? '').toString(),
  );
}

class GuideEnglishTest {
  const GuideEnglishTest({required this.summary, required this.parts});

  final String summary;
  final List<String> parts;

  factory GuideEnglishTest.fromJson(Map<String, dynamic> json) =>
      GuideEnglishTest(
        summary: (json['summary'] ?? '').toString(),
        parts: _strings(json['parts']),
      );
}

class GuideCivicsTest {
  const GuideCivicsTest({
    required this.summary,
    required this.variants,
    required this.note,
  });

  final String summary;
  final List<GuideCivicsVariant> variants;
  final String note;

  factory GuideCivicsTest.fromJson(Map<String, dynamic> json) =>
      GuideCivicsTest(
        summary: (json['summary'] ?? '').toString(),
        variants: [
          for (final v in _list(json['variants']))
            GuideCivicsVariant.fromJson(_map(v)),
        ],
        note: (json['note'] ?? '').toString(),
      );
}

class GuideCivicsVariant {
  const GuideCivicsVariant({
    required this.label,
    required this.detail,
    required this.version,
  });

  final String label;
  final String detail;

  /// The storage key of the matching [TestVersion], so the UI can offer to
  /// switch the user to the set their filing date actually buys them.
  final String version;

  factory GuideCivicsVariant.fromJson(Map<String, dynamic> json) =>
      GuideCivicsVariant(
        label: (json['label'] ?? '').toString(),
        detail: (json['detail'] ?? '').toString(),
        version: (json['version'] ?? '').toString(),
      );
}

class GuideExemption {
  const GuideExemption({required this.label, required this.detail});

  final String label;
  final String detail;

  factory GuideExemption.fromJson(Map<String, dynamic> json) => GuideExemption(
    label: (json['label'] ?? '').toString(),
    detail: (json['detail'] ?? '').toString(),
  );
}

class GuideLink {
  const GuideLink({required this.label, required this.url});

  final String label;
  final String url;

  factory GuideLink.fromJson(Map<String, dynamic> json) => GuideLink(
    label: (json['label'] ?? '').toString(),
    url: (json['url'] ?? '').toString(),
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

List<Object?> _list(Object? value) => value is List ? value : const [];

List<String> _strings(Object? value) => [
  for (final v in _list(value)) v.toString(),
];

int _int(Object? value) => value is num ? value.toInt() : 0;
