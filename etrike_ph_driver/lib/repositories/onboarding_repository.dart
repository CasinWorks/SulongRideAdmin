import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/onboarding_models.dart';
import '../core/onboarding_upload_utils.dart';

const _storageBucket = 'driver-documents';

class OnboardingRepository {
  OnboardingRepository(this._client);

  final SupabaseClient _client;

  String? get _driverId => _client.auth.currentUser?.id;

  Future<OnboardingBundle> fetchBundle() async {
    final id = _driverId;
    if (id == null) {
      return const OnboardingBundle();
    }
    await ensurePipeline(id);
    final draft = await fetchDraft(id);
    final pipeline = await fetchPipeline(id);
    final documents = await listDocuments(id);
    final assignedVehicle = await fetchAssignedVehicle(id, draft: draft);
    return OnboardingBundle(
      draft: draft,
      pipeline: pipeline,
      documents: documents,
      checklistPercent: computeChecklistPercent(documents),
      assignedVehicle: assignedVehicle,
    );
  }

  Future<AssignedVehicle?> fetchAssignedVehicle(
    String driverId, {
    RegistrationDraft? draft,
  }) async {
    try {
      final assigned = await _client
          .from('vehicles')
          .select('id, unit_number, plate_number, model')
          .eq('assigned_driver_id', driverId)
          .maybeSingle();
      if (assigned != null) {
        return AssignedVehicle.fromJson(assigned);
      }
      final resolvedDraft = draft ?? await fetchDraft(driverId);
      final vehicleId = resolvedDraft?.employment['vehicle_id']?.toString();
      if (vehicleId == null || vehicleId.isEmpty) return null;
      final row = await _client
          .from('vehicles')
          .select('id, unit_number, plate_number, model')
          .eq('id', vehicleId)
          .maybeSingle();
      if (row == null) return null;
      return AssignedVehicle.fromJson(row);
    } catch (_) {
      return null;
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

  Future<HiringPipelineState?> fetchPipeline(String driverId) async {
    try {
      final row = await _client
          .from('driver_hiring_pipeline')
          .select()
          .eq('driver_id', driverId)
          .maybeSingle();
      if (row == null) return null;
      final timeline = await fetchTimeline(driverId);
      return HiringPipelineState(
        stage: HiringStageX.fromDb(row['current_stage'] as String?),
        checklistPercent: (row['checklist_percent'] as num?)?.toInt() ?? 0,
        onboardingDueDate: row['onboarding_due_date'] != null
            ? DateTime.tryParse(row['onboarding_due_date'].toString())
            : null,
        timeline: timeline,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<OnboardingTimelineEntry>> fetchTimeline(String driverId,
      {int limit = 15}) async {
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
          at: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
              DateTime.now(),
          action: m['action'] as String? ?? '',
          summary: m['summary'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> ensurePipeline(String driverId) async {
    try {
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
      await _logTimeline(
        driverId: driverId,
        action: 'application_started',
        summary: 'Driver started onboarding in the app',
      );
    } catch (_) {
      // Optional until fix_driver_onboarding_complete.sql is applied in Supabase.
    }
  }

  Future<void> savePersonalInfo({
    required String firstName,
    required String lastName,
    required String contact,
    required String email,
    required String emergencyContact,
    required String address,
  }) async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');

    final fullName = [firstName.trim(), lastName.trim()]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final personalInfo = {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'contact': contact.trim(),
      'email': email.trim(),
      'emergency_contact': emergencyContact.trim(),
      'address': address.trim(),
    };

    await _client.from('drivers').update({
      'full_name': fullName.isEmpty ? 'Driver' : fullName,
      'phone': contact.trim(),
      'emergency_contact': emergencyContact.trim(),
    }).eq('id', id);

    await _client.from('driver_registration_drafts').upsert({
      'driver_id': id,
      'current_step': 2,
      'personal_info': personalInfo,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _logTimeline(
      driverId: id,
      action: 'personal_info_saved',
      summary: 'Personal information saved',
    );
  }

  Future<void> saveDraftStep(int step) async {
    final id = _driverId;
    if (id == null) return;
    await _client.from('driver_registration_drafts').upsert({
      'driver_id': id,
      'current_step': step.clamp(1, 7),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> removeDocument(DocumentType docType) async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');

    final docs = await listDocuments(id);
    final existing = docs.where((d) => d.docType == docType).firstOrNull;

    if (existing?.fileName != null) {
      try {
        await _client.storage.from(_storageBucket).remove([
          '$id/${docType.dbValue}/${existing!.fileName}',
        ]);
      } catch (_) {}
    }

    await _client.from('driver_documents').update({
      'file_url': null,
      'file_name': null,
      'status': DocumentStatus.pending.dbValue,
      'expiry_date': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('driver_id', id).eq('doc_type', docType.dbValue);

    if (docType == DocumentType.profilePhoto) {
      await _client.from('drivers').update({
        'profile_photo_url': null,
      }).eq('id', id);
    }

    await _syncChecklistPercent(id);
    await _logTimeline(
      driverId: id,
      action: 'document_removed',
      summary: 'Removed ${docType.label}',
      metadata: {'doc_type': docType.dbValue},
    );
  }

  Future<DriverDocumentRow> uploadDocument({
    required DocumentType docType,
    required Uint8List fileBytes,
    required String fileName,
    DateTime? expiryDate,
    String? documentNumber,
  }) async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');

    final safeName = sanitizeUploadFileName(fileName);
    final path = '$id/${docType.dbValue}/$safeName';

    try {
      await _client.storage.from(_storageBucket).uploadBinary(
            path,
            fileBytes,
            fileOptions: const FileOptions(upsert: true),
          );
    } catch (e) {
      throw StateError(formatOnboardingUploadError(e));
    }

    final publicUrl = _client.storage.from(_storageBucket).getPublicUrl(path);

    final payload = <String, dynamic>{
      'driver_id': id,
      'doc_type': docType.dbValue,
      'file_url': publicUrl,
      'file_name': safeName,
      'status': DocumentStatus.pending.dbValue,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (documentNumber != null && documentNumber.trim().isNotEmpty)
        'document_number': documentNumber.trim(),
      if (expiryDate != null)
        'expiry_date': expiryDate.toIso8601String().split('T').first,
    };

    final row = await _client
        .from('driver_documents')
        .upsert(payload, onConflict: 'driver_id,doc_type')
        .select()
        .single();

    if (docType == DocumentType.profilePhoto) {
      await _client.from('drivers').update({
        'profile_photo_url': publicUrl,
      }).eq('id', id);
    }

    await _syncChecklistPercent(id);
    await _logTimeline(
      driverId: id,
      action: 'document_uploaded',
      summary: 'Uploaded ${docType.label}',
      metadata: {'doc_type': docType.dbValue},
    );

    return DriverDocumentRow.fromJson(row);
  }

  Future<void> submitApplication() async {
    final id = _driverId;
    if (id == null) throw StateError('Not signed in');

    final docs = await listDocuments(id);
    final pct = computeChecklistPercent(docs);
    if (pct < 100) {
      throw StateError(
        'Upload all required documents before submitting ($pct% complete).',
      );
    }

    await _client.from('driver_hiring_pipeline').upsert({
      'driver_id': id,
      'current_stage': 'onboarding',
      'stage_status': 'in_progress',
      'checklist_percent': pct,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'driver_id');

    await _client.from('driver_registration_drafts').upsert({
      'driver_id': id,
      'current_step': 6,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await _logTimeline(
      driverId: id,
      action: 'application_submitted',
      summary: 'Application submitted for operator review',
    );
  }

  Future<void> _syncChecklistPercent(String driverId) async {
    try {
      final docs = await listDocuments(driverId);
      final pct = computeChecklistPercent(docs);
      await _client.from('driver_hiring_pipeline').upsert({
        'driver_id': driverId,
        'checklist_percent': pct,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'driver_id');
    } catch (_) {}
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
