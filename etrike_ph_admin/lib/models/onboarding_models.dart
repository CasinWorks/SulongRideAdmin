/// E-trike company driver onboarding: hiring pipeline + document checklist.

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
        HiringStage.interviewScheduled => 'Interview',
        HiringStage.interviewCompleted => 'Interview done',
        HiringStage.offerHiring => 'Hiring',
        HiringStage.onboarding => 'Onboarding',
        HiringStage.contractSigning => 'Contract',
        HiringStage.approvedActive => 'Active',
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

  int get orderIndex => HiringStage.values.indexOf(this);

  int get pipelinePercent {
    final idx = orderIndex;
    final total = HiringStage.values.length - 1;
    if (total <= 0) return 0;
    return ((idx / total) * 100).round().clamp(0, 100);
  }
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
  psaBirth,
  medicalCert,
  drugTest,
  sss,
  philhealth,
  pagibig,
  tin,
  contractSigned,
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
        DocumentType.psaBirth => 'psa_birth',
        DocumentType.medicalCert => 'medical_cert',
        DocumentType.drugTest => 'drug_test',
        DocumentType.sss => 'sss',
        DocumentType.philhealth => 'philhealth',
        DocumentType.pagibig => 'pagibig',
        DocumentType.tin => 'tin',
        DocumentType.contractSigned => 'contract_signed',
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
        DocumentType.psaBirth => 'PSA Birth Certificate',
        DocumentType.medicalCert => 'Medical Certificate',
        DocumentType.drugTest => 'Drug Test Result',
        DocumentType.sss => 'SSS member data',
        DocumentType.philhealth => 'PhilHealth',
        DocumentType.pagibig => 'Pag-IBIG',
        DocumentType.tin => 'TIN (BIR)',
        DocumentType.contractSigned => 'Signed employment contract',
      };

  bool get doesNotExpire => this == DocumentType.psaBirth;

  int get wizardStep => switch (this) {
        DocumentType.profilePhoto || DocumentType.validId => 1,
        DocumentType.pdl ||
        DocumentType.ltoOr ||
        DocumentType.ltoCr ||
        DocumentType.ltfrbCpc =>
          2,
        DocumentType.nbi ||
        DocumentType.policeClearance ||
        DocumentType.barangayClearance ||
        DocumentType.psaBirth =>
          3,
        DocumentType.medicalCert || DocumentType.drugTest => 4,
        DocumentType.sss || DocumentType.philhealth || DocumentType.pagibig || DocumentType.tin => 5,
        DocumentType.contractSigned => 7,
      };
}

/// Required docs for company e-trike drivers (operator-owned fleet).
const kRequiredDriverDocuments = <DocumentType>[
  DocumentType.profilePhoto,
  DocumentType.validId,
  DocumentType.pdl,
  DocumentType.ltoOr,
  DocumentType.ltoCr,
  DocumentType.ltfrbCpc,
  DocumentType.nbi,
  DocumentType.policeClearance,
  DocumentType.barangayClearance,
  DocumentType.psaBirth,
  DocumentType.medicalCert,
  DocumentType.drugTest,
  DocumentType.contractSigned,
];

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
}

class VehicleRow {
  const VehicleRow({
    required this.id,
    required this.unitNumber,
    required this.plateNumber,
    this.model,
    required this.status,
    this.assignedDriverId,
    this.boundaryFee = 0,
  });

  final String id;
  final String unitNumber;
  final String plateNumber;
  final String? model;
  final String status;
  final String? assignedDriverId;
  final double boundaryFee;

  factory VehicleRow.fromJson(Map<String, dynamic> json) => VehicleRow(
        id: json['id'] as String,
        unitNumber: json['unit_number'] as String,
        plateNumber: json['plate_number'] as String,
        model: json['model'] as String?,
        status: json['status'] as String? ?? 'available',
        assignedDriverId: json['assigned_driver_id'] as String?,
        boundaryFee: (json['boundary_fee'] as num?)?.toDouble() ?? 0,
      );

  String get displayLabel => '$unitNumber · $plateNumber';
}

class DriverDocumentRow {
  const DriverDocumentRow({
    required this.id,
    required this.driverId,
    required this.docType,
    this.documentNumber,
    this.fileUrl,
    this.fileName,
    this.issueDate,
    this.expiryDate,
    required this.status,
    this.adminNotes,
    this.verifiedAt,
    this.vehicleId,
  });

  final String id;
  final String driverId;
  final DocumentType docType;
  final String? documentNumber;
  final String? fileUrl;
  final String? fileName;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DocumentStatus status;
  final String? adminNotes;
  final DateTime? verifiedAt;
  final String? vehicleId;

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final today = DateTime.now();
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    final now = DateTime(today.year, today.month, today.day);
    return exp.difference(now).inDays;
  }

  factory DriverDocumentRow.fromJson(Map<String, dynamic> json) {
    final type = DocumentTypeX.fromDb(json['doc_type'] as String?) ?? DocumentType.validId;
    return DriverDocumentRow(
      id: json['id'] as String,
      driverId: json['driver_id'] as String,
      docType: type,
      documentNumber: json['document_number'] as String?,
      fileUrl: json['file_url'] as String?,
      fileName: json['file_name'] as String?,
      issueDate: json['issue_date'] != null
          ? DateTime.tryParse(json['issue_date'] as String)
          : null,
      expiryDate: json['expiry_date'] != null
          ? DateTime.tryParse(json['expiry_date'] as String)
          : null,
      status: DocumentStatusX.fromDb(json['status'] as String?),
      adminNotes: json['admin_notes'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'] as String)
          : null,
      vehicleId: json['vehicle_id'] as String?,
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
        driverId: json['driver_id'] as String,
        currentStep: (json['current_step'] as num?)?.toInt() ?? 1,
        personalInfo: Map<String, dynamic>.from(json['personal_info'] as Map? ?? {}),
        employment: Map<String, dynamic>.from(json['employment'] as Map? ?? {}),
      );
}

int computeChecklistPercent(List<DriverDocumentRow> docs) {
  if (kRequiredDriverDocuments.isEmpty) return 0;
  var done = 0;
  for (final required in kRequiredDriverDocuments) {
    final row = docs.cast<DriverDocumentRow?>().firstWhere(
          (d) => d?.docType == required,
          orElse: () => null,
        );
    if (row == null) continue;
    if (row.fileUrl != null &&
        (row.status == DocumentStatus.verified ||
            row.status == DocumentStatus.pending ||
            row.status == DocumentStatus.doesNotExpire ||
            row.status == DocumentStatus.expiringSoon)) {
      done++;
    }
  }
  return ((done / kRequiredDriverDocuments.length) * 100).round();
}

const kRegistrationStepLabels = [
  'Personal Info',
  'License & LTO',
  'Clearances',
  'Health & Drug',
  'Contributions',
  'Employment',
  'Review',
];

class OnboardingTimelineEntry {
  const OnboardingTimelineEntry({
    required this.at,
    required this.action,
    required this.summary,
    this.actorName,
  });

  final DateTime at;
  final String action;
  final String summary;
  final String? actorName;
}

class HiringPipelineState {
  const HiringPipelineState({
    required this.stage,
    this.pipelinePercent = 0,
    this.checklistPercent = 0,
    this.interviewAt,
    this.contractDueDate,
    this.onboardingDueDate,
    this.lastReminderAt,
    this.timeline = const [],
  });

  final HiringStage stage;
  final int pipelinePercent;
  final int checklistPercent;
  final DateTime? interviewAt;
  final DateTime? contractDueDate;
  final DateTime? onboardingDueDate;
  final DateTime? lastReminderAt;
  final List<OnboardingTimelineEntry> timeline;

  int get effectivePipelinePercent =>
      pipelinePercent > 0 ? pipelinePercent : stage.pipelinePercent;

  HiringPipelineState copyWith({int? checklistPercent, HiringStage? stage}) =>
      HiringPipelineState(
        stage: stage ?? this.stage,
        pipelinePercent: pipelinePercent,
        checklistPercent: checklistPercent ?? this.checklistPercent,
        interviewAt: interviewAt,
        contractDueDate: contractDueDate,
        onboardingDueDate: onboardingDueDate,
        lastReminderAt: lastReminderAt,
        timeline: timeline,
      );
}
