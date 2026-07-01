import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_models.dart';
import 'audit_repository.dart';

const _storageBucket = 'driver-documents';

class OnboardingRepository {
  OnboardingRepository(this._client) : _audit = AuditRepository(_client);

  final SupabaseClient _client;
  final AuditRepository _audit;

  Future<List<VehicleRow>> listAvailableVehicles({String? forDriverId}) async {
    try {
      final rows = await _client.from('vehicles').select().order('unit_number');
      return (rows as List<dynamic>)
          .map((e) => VehicleRow.fromJson(e as Map<String, dynamic>))
          .where((v) =>
              v.status == 'available' ||
              (forDriverId != null && v.assignedDriverId == forDriverId))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DriverDocumentRow>> listDocuments(String driverId) async {
    try {
      final rows =
          await _client.from('driver_documents').select().eq('driver_id', driverId);
      return (rows as List<dynamic>)
          .map((e) => DriverDocumentRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DriverDocumentRow>> listExpiringDocuments({int withinDays = 30}) async {
    try {
      final cutoff = DateTime.now().add(Duration(days: withinDays));
      final rows = await _client
          .from('driver_documents')
          .select('*, drivers(full_name, email)')
          .not('expiry_date', 'is', null)
          .lte('expiry_date', cutoff.toIso8601String().split('T').first)
          .gte('expiry_date', DateTime.now().toIso8601String().split('T').first);
      return (rows as List<dynamic>)
          .map((e) => DriverDocumentRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<DriverDocumentRow>> listExpiredDocuments() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows = await _client
          .from('driver_documents')
          .select('*, drivers(full_name, email)')
          .not('expiry_date', 'is', null)
          .lt('expiry_date', today);
      return (rows as List<dynamic>)
          .map((e) => DriverDocumentRow.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<HiringPipelineState?> fetchPipeline(String driverId) async {
    try {
      final row = await _client
          .from('driver_hiring_pipeline')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      if (row == null) return null;
      final timeline = await fetchTimeline(driverId, limit: 20);
      return HiringPipelineState(
        stage: HiringStageX.fromDb(row['current_stage'] as String?),
        pipelinePercent: (row['pipeline_percent'] as num?)?.toInt() ?? 0,
        checklistPercent: (row['checklist_percent'] as num?)?.toInt() ?? 0,
        interviewAt: row['interview_at'] != null
            ? DateTime.tryParse(row['interview_at'] as String)
            : null,
        contractDueDate: row['contract_due_date'] != null
            ? DateTime.tryParse(row['contract_due_date'] as String)
            : null,
        onboardingDueDate: row['onboarding_due_date'] != null
            ? DateTime.tryParse(row['onboarding_due_date'] as String)
            : null,
        lastReminderAt: row['last_reminder_at'] != null
            ? DateTime.tryParse(row['last_reminder_at'] as String)
            : null,
        timeline: timeline,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<OnboardingTimelineEntry>> fetchTimeline(String driverId, {int limit = 30}) async {
    try {
      final rows = await _client
          .from('onboarding_timeline')
          .select()
          .eq('driver_id', driverId)
          .order('created_at', ascending: false)
          .limit(limit);
      return (rows as List<dynamic>).map((e) {
        final m = e as Map<String, dynamic>;
        return OnboardingTimelineEntry(
          at: DateTime.parse(m['created_at'] as String),
          action: m['action'] as String,
          summary: m['summary'] as String,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<({String driverId, String name, HiringStage stage, DateTime? due})>>
      listOverdueOnboarding() async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      final rows = await _client
          .from('driver_hiring_pipeline')
          .select('*, drivers(full_name, email)')
          .lt('onboarding_due_date', today)
          .neq('current_stage', 'approved_active');
      return (rows as List<dynamic>).map((e) {
        final m = e as Map<String, dynamic>;
        final drivers = m['drivers'] as Map<String, dynamic>?;
        final name = drivers?['full_name'] as String? ??
            drivers?['email'] as String? ??
            'Applicant';
        return (
          driverId: m['driver_id'] as String,
          name: name,
          stage: HiringStageX.fromDb(m['current_stage'] as String?),
          due: m['onboarding_due_date'] != null
              ? DateTime.tryParse(m['onboarding_due_date'] as String)
              : null,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<({String driverId, String name, DateTime interviewAt})>> listInterviewsDue() async {
    try {
      final now = DateTime.now();
      final end = now.add(const Duration(days: 1));
      final rows = await _client
          .from('driver_hiring_pipeline')
          .select('*, drivers(full_name, email)')
          .eq('current_stage', 'interview_scheduled')
          .not('interview_at', 'is', null)
          .lte('interview_at', end.toUtc().toIso8601String());
      return (rows as List<dynamic>).map((e) {
        final m = e as Map<String, dynamic>;
        final drivers = m['drivers'] as Map<String, dynamic>?;
        return (
          driverId: m['driver_id'] as String,
          name: drivers?['full_name'] as String? ?? drivers?['email'] as String? ?? 'Applicant',
          interviewAt: DateTime.parse(m['interview_at'] as String),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<RegistrationDraft?> fetchDraft(String driverId) async {
    try {
      final row = await _client
          .from('driver_registration_drafts')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      if (row == null) return null;
      return RegistrationDraft.fromJson(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> ensurePipeline(String driverId) async {
    final existing = await _client
        .from('driver_hiring_pipeline')
        .select('id')
        .eq('driver_id', driverId)
        .maybeSingle();
    if (existing != null) return;
    await _client.from('driver_hiring_pipeline').insert({
      'driver_id': driverId,
      'current_stage': 'application',
      'stage_status': 'in_progress',
    });
  }

  Future<void> saveDraft({
    required String driverId,
    required int currentStep,
    Map<String, dynamic>? personalInfo,
    Map<String, dynamic>? employment,
  }) async {
    await _client.from('driver_registration_drafts').upsert({
      'driver_id': driverId,
      'current_step': currentStep,
      if (personalInfo != null) 'personal_info': personalInfo,
      if (employment != null) 'employment': employment,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updatePipelineStage({
    required String driverId,
    required HiringStage stage,
    int? checklistPercent,
  }) async {
    await ensurePipeline(driverId);
    await _client.from('driver_hiring_pipeline').update({
      'current_stage': stage.dbValue,
      'pipeline_percent': stage.pipelinePercent,
      if (checklistPercent != null) 'checklist_percent': checklistPercent,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _logTimeline(
      driverId: driverId,
      action: 'stage_update',
      summary: 'Pipeline moved to ${stage.label}',
      metadata: {'stage': stage.dbValue},
    );
  }

  Future<void> setDeadline({
    required String driverId,
    required DateTime date,
    required String kind,
  }) async {
    await ensurePipeline(driverId);
    final field = kind == 'contract' ? 'contract_due_date' : 'onboarding_due_date';
    await _client.from('driver_hiring_pipeline').update({
      field: date.toIso8601String().split('T').first,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _logTimeline(
      driverId: driverId,
      action: 'deadline_set',
      summary: 'Deadline set to ${date.year}-${date.month}-${date.day} ($kind)',
      metadata: {'kind': kind, 'date': date.toIso8601String()},
    );
  }

  Future<void> sendReminder({
    required String driverId,
    required String summary,
    String action = 'reminder_sent',
  }) async {
    await _client.from('driver_hiring_pipeline').update({
      'last_reminder_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('driver_id', driverId);
    await _logTimeline(driverId: driverId, action: action, summary: summary);
    await _audit.log(
      action: 'onboarding.reminder',
      entityType: 'drivers',
      entityId: driverId,
      summary: summary,
    );
  }

  Future<DriverDocumentRow> upsertDocument({
    required String driverId,
    required DocumentType docType,
    Uint8List? fileBytes,
    String? fileName,
    String? documentNumber,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? vehicleId,
    DocumentStatus status = DocumentStatus.pending,
  }) async {
    String? publicUrl;
    if (fileBytes != null && fileName != null) {
      final path = '$driverId/${docType.dbValue}/$fileName';
      await _client.storage.from(_storageBucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );
      publicUrl = _client.storage.from(_storageBucket).getPublicUrl(path);
    }

    final payload = <String, dynamic>{
      'driver_id': driverId,
      'doc_type': docType.dbValue,
      if (documentNumber != null) 'document_number': documentNumber,
      if (publicUrl != null) 'file_url': publicUrl,
      if (fileName != null) 'file_name': fileName,
      if (issueDate != null) 'issue_date': issueDate.toIso8601String().split('T').first,
      if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String().split('T').first,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      'status': docType.doesNotExpire ? 'does_not_expire' : status.dbValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    final row = await _client
        .from('driver_documents')
        .upsert(payload, onConflict: 'driver_id,doc_type')
        .select()
        .single();

    await _syncChecklistPercent(driverId);
    await _audit.log(
      action: 'document.upload',
      entityType: 'driver_documents',
      entityId: driverId,
      summary: 'Uploaded ${docType.label}',
      metadata: {'doc_type': docType.dbValue},
    );

    return DriverDocumentRow.fromJson(row);
  }

  Future<void> verifyDocument({
    required String documentId,
    required String driverId,
    required DocumentStatus status,
    String? adminNotes,
  }) async {
    final uid = _client.auth.currentUser?.id;
    await _client.from('driver_documents').update({
      'status': status.dbValue,
      if (adminNotes != null) 'admin_notes': adminNotes,
      if (status == DocumentStatus.verified) 'verified_by': uid,
      if (status == DocumentStatus.verified)
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', documentId);
    await _syncChecklistPercent(driverId);
  }

  Future<void> assignVehicle({
    required String vehicleId,
    required String driverId,
    String? plateNumber,
  }) async {
    await _client.from('vehicles').update({
      'assigned_driver_id': driverId,
      'status': 'assigned',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', vehicleId);
    if (plateNumber != null) {
      await _client.from('drivers').update({
        'trike_plate_number': plateNumber,
      }).eq('id', driverId);
    }
  }

  Future<void> approveRegistration({
    required String driverId,
    bool withExceptions = false,
    String? notes,
  }) async {
    await _client.from('drivers').update({
      'approval_status': 'approved',
    }).eq('id', driverId);
    await updatePipelineStage(driverId: driverId, stage: HiringStage.approvedActive);
    await _audit.log(
      action: withExceptions ? 'driver.approve_exceptions' : 'driver.approve',
      entityType: 'drivers',
      entityId: driverId,
      summary: withExceptions
          ? 'Driver approved with exceptions'
          : 'Driver registration approved',
      metadata: notes != null ? {'notes': notes} : null,
    );
  }

  Future<void> rejectRegistration({
    required String driverId,
    required String reason,
  }) async {
    await _client.from('drivers').update({
      'approval_status': 'rejected',
      'is_online': false,
      'is_available': false,
    }).eq('id', driverId);
    await _logTimeline(
      driverId: driverId,
      action: 'rejected',
      summary: reason,
    );
    await _audit.log(
      action: 'driver.reject',
      entityType: 'drivers',
      entityId: driverId,
      summary: 'Registration rejected: $reason',
    );
  }

  Future<void> _syncChecklistPercent(String driverId) async {
    final docs = await listDocuments(driverId);
    final pct = computeChecklistPercent(docs);
    await _client.from('driver_hiring_pipeline').upsert({
      'driver_id': driverId,
      'checklist_percent': pct,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'driver_id');
  }

  Future<void> _logTimeline({
    required String driverId,
    required String action,
    required String summary,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _client.auth.currentUser?.id;
    try {
      await _client.from('onboarding_timeline').insert({
        'driver_id': driverId,
        'actor_id': uid,
        'action': action,
        'summary': summary,
        'metadata': metadata ?? {},
      });
    } catch (_) {}
  }
}
