/// Driver self-service onboarding — mirrors admin portal checklist.
library;

enum HiringStage {
  application,
  interviewScheduled,
  interviewCompleted,
  offerHiring,
  onboarding,
  contractSigning,
  approvedActive,
}

extension HiringStageX on HiringStage {
  String get label => switch (this) {
        HiringStage.application => 'Application',
        HiringStage.interviewScheduled => 'Interview scheduled',
        HiringStage.interviewCompleted => 'Interview completed',
        HiringStage.offerHiring => 'Offer / hiring',
        HiringStage.onboarding => 'Document review',
        HiringStage.contractSigning => 'Contract signing',
        HiringStage.approvedActive => 'Approved',
      };

  String get dbValue => switch (this) {
        HiringStage.application => 'application',
        HiringStage.interviewScheduled => 'interview_scheduled',
        HiringStage.interviewCompleted => 'interview_completed',
        HiringStage.offerHiring => 'offer_hiring',
        HiringStage.onboarding => 'onboarding',
        HiringStage.contractSigning => 'contract_signing',
        HiringStage.approvedActive => 'approved_active',
      };

  static HiringStage fromDb(String? v) => switch (v) {
        'interview_scheduled' => HiringStage.interviewScheduled,
        'interview_completed' => HiringStage.interviewCompleted,
        'offer_hiring' => HiringStage.offerHiring,
        'onboarding' => HiringStage.onboarding,
        'contract_signing' => HiringStage.contractSigning,
        'approved_active' => HiringStage.approvedActive,
        _ => HiringStage.application,
      };
}

enum DocumentType {
  profilePhoto,
  validId,
  pdl,
  ltoOr,
  ltoCr,
  ltfrbCpc,
  nbi,
  policeClearance,
  barangayClearance,
  medicalCert,
  drugTest,
}

extension DocumentTypeX on DocumentType {
  String get dbValue => switch (this) {
        DocumentType.profilePhoto => 'profile_photo',
        DocumentType.validId => 'valid_id',
        DocumentType.pdl => 'pdl',
        DocumentType.ltoOr => 'lto_or',
        DocumentType.ltoCr => 'lto_cr',
        DocumentType.ltfrbCpc => 'ltfrb_cpc',
        DocumentType.nbi => 'nbi',
        DocumentType.policeClearance => 'police_clearance',
        DocumentType.barangayClearance => 'barangay_clearance',
        DocumentType.medicalCert => 'medical_cert',
        DocumentType.drugTest => 'drug_test',
      };

  static DocumentType? fromDb(String? v) {
    if (v == null) return null;
    for (final t in DocumentType.values) {
      if (t.dbValue == v) return t;
    }
    return null;
  }

  String get label => switch (this) {
        DocumentType.profilePhoto => 'Profile photo',
        DocumentType.validId => 'Valid government ID',
        DocumentType.pdl => "Professional Driver's License (PDL)",
        DocumentType.ltoOr => 'LTO Official Receipt (OR)',
        DocumentType.ltoCr => 'LTO Certificate of Registration (CR)',
        DocumentType.ltfrbCpc => 'LTFRB Franchise / CPC',
        DocumentType.nbi => 'NBI Clearance',
        DocumentType.policeClearance => 'Police Clearance',
        DocumentType.barangayClearance => 'Barangay Clearance',
        DocumentType.medicalCert => 'Medical Certificate',
        DocumentType.drugTest => 'Drug Test Result',
      };

  bool get needsExpiry => this != DocumentType.profilePhoto;

  int get wizardStep => switch (this) {
        DocumentType.profilePhoto || DocumentType.validId => 2,
        DocumentType.pdl || DocumentType.ltfrbCpc => 3,
        DocumentType.nbi ||
        DocumentType.policeClearance ||
        DocumentType.barangayClearance =>
          4,
        DocumentType.medicalCert || DocumentType.drugTest => 5,
        DocumentType.ltoOr || DocumentType.ltoCr => 3,
      };
}

const kRequiredDriverDocuments = <DocumentType>[
  DocumentType.profilePhoto,
  DocumentType.validId,
  DocumentType.pdl,
  DocumentType.ltfrbCpc,
  DocumentType.nbi,
  DocumentType.policeClearance,
  DocumentType.barangayClearance,
  DocumentType.medicalCert,
  DocumentType.drugTest,
];

const kDriverOnboardingStepLabels = [
  'Personal info',
  'Profile & ID',
  "Driver's license",
  'Clearances',
  'Health',
  'Rider training',
  'Review',
];

const kDocumentsByWizardStep = <int, List<DocumentType>>{
  2: [DocumentType.profilePhoto, DocumentType.validId],
  3: [DocumentType.pdl, DocumentType.ltfrbCpc],
  4: [
    DocumentType.nbi,
    DocumentType.policeClearance,
    DocumentType.barangayClearance,
  ],
  5: [DocumentType.medicalCert, DocumentType.drugTest],
};

enum DocumentStatus {
  pending,
  verified,
  rejected,
  expiringSoon,
  expired,
  notRequired,
  doesNotExpire,
}

extension DocumentStatusX on DocumentStatus {
  String get dbValue => switch (this) {
        DocumentStatus.pending => 'pending',
        DocumentStatus.verified => 'verified',
        DocumentStatus.rejected => 'rejected',
        DocumentStatus.expiringSoon => 'expiring_soon',
        DocumentStatus.expired => 'expired',
        DocumentStatus.notRequired => 'not_required',
        DocumentStatus.doesNotExpire => 'does_not_expire',
      };

  static DocumentStatus fromDb(String? v) => switch (v) {
        'verified' => DocumentStatus.verified,
        'rejected' => DocumentStatus.rejected,
        'expiring_soon' => DocumentStatus.expiringSoon,
        'expired' => DocumentStatus.expired,
        'not_required' => DocumentStatus.notRequired,
        'does_not_expire' => DocumentStatus.doesNotExpire,
        _ => DocumentStatus.pending,
      };

  bool get isUploaded =>
      this == DocumentStatus.pending ||
      this == DocumentStatus.verified ||
      this == DocumentStatus.expiringSoon ||
      this == DocumentStatus.doesNotExpire;
}

class DriverDocumentRow {
  const DriverDocumentRow({
    required this.id,
    required this.driverId,
    required this.docType,
    this.documentNumber,
    this.fileUrl,
    this.fileName,
    this.expiryDate,
    required this.status,
    this.adminNotes,
  });

  final String id;
  final String driverId;
  final DocumentType docType;
  final String? documentNumber;
  final String? fileUrl;
  final String? fileName;
  final DateTime? expiryDate;
  final DocumentStatus status;
  final String? adminNotes;

  factory DriverDocumentRow.fromJson(Map<String, dynamic> json) {
    final type =
        DocumentTypeX.fromDb(json['doc_type'] as String?) ?? DocumentType.validId;
    return DriverDocumentRow(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id']?.toString() ?? '',
      docType: type,
      documentNumber: json['document_number'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'].toString())
          : null,
      status: DocumentStatusX.fromDb(json['status'] as String?),
      adminNotes: json['admin_notes'] as String?,
    );
  }
}

class RegistrationDraft {
  const RegistrationDraft({
    required this.driverId,
    required this.currentStep,
    this.personalInfo = const {},
    this.employment = const {},
  });

  final String driverId;
  final int currentStep;
  final Map<String, dynamic> personalInfo;
  final Map<String, dynamic> employment;

  factory RegistrationDraft.fromJson(Map<String, dynamic> json) => RegistrationDraft(
        driverId: json['driver_id']?.toString() ?? '',
        currentStep: (json['current_step'] as num?)?.toInt().clamp(1, 7) ?? 1,
        personalInfo:
            Map<String, dynamic>.from(json['personal_info'] as Map? ?? {}),
        employment: Map<String, dynamic>.from(json['employment'] as Map? ?? {}),
      );
}

class AssignedVehicle {
  const AssignedVehicle({
    required this.id,
    required this.unitNumber,
    required this.plateNumber,
    this.model,
  });

  final String id;
  final String unitNumber;
  final String plateNumber;
  final String? model;

  String get displayLabel {
    final base = 'Unit $unitNumber · $plateNumber';
    return model == null || model!.isEmpty ? base : '$base ($model)';
  }

  factory AssignedVehicle.fromJson(Map<String, dynamic> json) => AssignedVehicle(
        id: json['id']?.toString() ?? '',
        unitNumber: json['unit_number']?.toString() ?? '',
        plateNumber: json['plate_number']?.toString() ?? '',
        model: json['model'] as String?,
      );
}

class OnboardingTimelineEntry {
  const OnboardingTimelineEntry({
    required this.at,
    required this.action,
    required this.summary,
  });

  final DateTime at;
  final String action;
  final String summary;
}

class HiringPipelineState {
  const HiringPipelineState({
    required this.stage,
    this.checklistPercent = 0,
    this.onboardingDueDate,
    this.timeline = const [],
  });

  final HiringStage stage;
  final int checklistPercent;
  final DateTime? onboardingDueDate;
  final List<OnboardingTimelineEntry> timeline;
}

class OnboardingBundle {
  const OnboardingBundle({
    this.draft,
    this.pipeline,
    this.documents = const [],
    this.checklistPercent = 0,
    this.assignedVehicle,
  });

  final RegistrationDraft? draft;
  final HiringPipelineState? pipeline;
  final List<DriverDocumentRow> documents;
  final int checklistPercent;
  final AssignedVehicle? assignedVehicle;

  DriverDocumentRow? doc(DocumentType type) {
    for (final d in documents) {
      if (d.docType == type) return d;
    }
    return null;
  }
}

int computeChecklistPercent(List<DriverDocumentRow> docs) {
  if (kRequiredDriverDocuments.isEmpty) return 0;
  var done = 0;
  for (final required in kRequiredDriverDocuments) {
    final row = docs.where((d) => d.docType == required).firstOrNull;
    if (row == null) continue;
    if (row.fileUrl != null && row.status.isUploaded) done++;
  }
  return ((done / kRequiredDriverDocuments.length) * 100).round();
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
