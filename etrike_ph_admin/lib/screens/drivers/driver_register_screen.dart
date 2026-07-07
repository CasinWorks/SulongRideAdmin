import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/admin_tokens.dart';
import '../../models/driver_row.dart';
import '../../models/onboarding_models.dart';
import '../../providers/admin_provider.dart';
import '../../widgets/admin_ui.dart';
import '../../widgets/document_status_badge.dart';
import '../../widgets/onboarding_progress.dart';

class DriverRegisterScreen extends ConsumerStatefulWidget {
  const DriverRegisterScreen({super.key, this.driverId});

  final String? driverId;

  @override
  ConsumerState<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends ConsumerState<DriverRegisterScreen> {
  var _step = 1;
  final _completed = <int>{};
  String? _selectedDriverId;
  HiringPipelineState _pipeline = const HiringPipelineState(stage: HiringStage.application);
  List<OnboardingTimelineEntry> _timeline = [];
  List<DriverDocumentRow> _loadedDocs = [];
  List<VehicleRow> _vehicles = [];
  bool _loading = true;

  // Step 1
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  DateTime? _dob;
  String _sex = 'Male';
  String _civilStatus = 'Single';
  final _nationality = TextEditingController(text: 'Filipino');
  final _street = TextEditingController();
  final _barangay = TextEditingController();
  final _city = TextEditingController();
  final _province = TextEditingController();
  final _zip = TextEditingController();
  final _contact = TextEditingController();
  final _email = TextEditingController();
  final _emergencyName = TextEditingController();
  final _emergencyRelation = TextEditingController();
  final _emergencyPhone = TextEditingController();

  // Step 6
  String _employmentType = 'Regular';
  String _shift = 'Morning (5AM–1PM)';
  String? _assignedUnit;
  final _boundaryFee = TextEditingController(text: '350');
  final _perTripRate = TextEditingController(text: '45');
  DateTime? _startDate;
  DateTime? _probationEnd;

  // Document tracking (file name + status per type)
  final _docFiles = <DocumentType, String>{};
  final _docStatus = <DocumentType, DocumentStatus>{};

  final _exceptionNotes = TextEditingController();
  final _rejectReason = TextEditingController();
  final _moreInfoNotes = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDriverId = widget.driverId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_selectedDriverId == null) {
      setState(() => _loading = false);
      return;
    }
    final repo = ref.read(onboardingRepositoryProvider);
    final admin = ref.read(adminRepositoryProvider);
    try {
      await repo.ensurePipeline(_selectedDriverId!);
      final pipeline = await repo.fetchPipeline(_selectedDriverId!);
      final docs = await repo.listDocuments(_selectedDriverId!);
      final draft = await repo.fetchDraft(_selectedDriverId!);
      final vehicles = await repo.listAvailableVehicles(forDriverId: _selectedDriverId);
      final driver = await admin.fetchDriver(_selectedDriverId!);
      if (!mounted) return;
      setState(() {
        _pipeline = pipeline ?? const HiringPipelineState(stage: HiringStage.application);
        _timeline = _pipeline.timeline;
        _loadedDocs = docs;
        _vehicles = vehicles;
        _loading = false;
        if (draft != null) _step = draft.currentStep;
        _hydrateDocs(docs);
        if (driver != null) _hydrateDriver(driver, draft);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError('$e');
      }
    }
  }

  void _hydrateDocs(List<DriverDocumentRow> docs) {
    for (final d in docs) {
      _docFiles[d.docType] = d.fileName ?? 'uploaded';
      _docStatus[d.docType] = d.status;
    }
  }

  void _hydrateDriver(DriverRow driver, RegistrationDraft? draft) {
    if (draft != null && draft.personalInfo.isNotEmpty) {
      _firstName.text = draft.personalInfo['first_name'] as String? ?? '';
      _lastName.text = draft.personalInfo['last_name'] as String? ?? '';
      _contact.text = draft.personalInfo['contact'] as String? ?? driver.phone ?? '';
      return;
    }
    final parts = driver.fullName.split(' ');
    if (parts.isNotEmpty) _firstName.text = parts.first;
    if (parts.length > 1) _lastName.text = parts.sublist(1).join(' ');
    _contact.text = driver.phone ?? '';
    _email.text = driver.email;
  }

  @override
  void dispose() {
    for (final c in [
      _firstName,
      _middleName,
      _lastName,
      _nationality,
      _street,
      _barangay,
      _city,
      _province,
      _zip,
      _contact,
      _email,
      _emergencyName,
      _emergencyRelation,
      _emergencyPhone,
      _boundaryFee,
      _perTripRate,
      _exceptionNotes,
      _rejectReason,
      _moreInfoNotes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int get _checklistPercent => computeChecklistPercent(_loadedDocs);

  bool get _step1Valid =>
      _firstName.text.trim().isNotEmpty &&
      _lastName.text.trim().isNotEmpty &&
      _dob != null &&
      _ageAtLeast18(_dob!) &&
      _street.text.trim().isNotEmpty &&
      _contact.text.trim().length >= 11;

  bool _ageAtLeast18(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age >= 18;
  }

  void _markStepComplete(int step) => setState(() => _completed.add(step));

  void _goToStep(int step) {
    if (step > _step && !_canUnlock(step)) return;
    setState(() => _step = step);
  }

  bool _canUnlock(int target) {
    for (var s = 1; s < target; s++) {
      if (!_completed.contains(s)) return false;
    }
    return true;
  }

  void _nextStep() async {
    if (_step == 1 && !_step1Valid) {
      _showError('Complete required personal info (driver must be 18+).');
      return;
    }
    if (_selectedDriverId == null) {
      _showError('Select a pending driver applicant first.');
      return;
    }
    _markStepComplete(_step);
    await _persistDraft();
    if (_step < 7) setState(() => _step++);
  }

  Future<void> _persistDraft() async {
    if (_selectedDriverId == null) return;
    await ref.read(onboardingRepositoryProvider).saveDraft(
          driverId: _selectedDriverId!,
          currentStep: _step,
          personalInfo: {
            'first_name': _firstName.text.trim(),
            'middle_name': _middleName.text.trim(),
            'last_name': _lastName.text.trim(),
            'contact': _contact.text.trim(),
            'email': _email.text.trim(),
          },
          employment: {
            'type': _employmentType,
            'shift': _shift,
            'unit': _assignedUnit,
            'boundary_fee': _boundaryFee.text,
            'per_trip_rate': _perTripRate.text,
          },
        );
  }

  void _prevStep() {
    if (_step > 1) setState(() => _step--);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _sendReminder() async {
    if (_selectedDriverId == null) return;
    await ref.read(onboardingRepositoryProvider).sendReminder(
          driverId: _selectedDriverId!,
          summary: 'Reminder sent for ${_pipeline.stage.label} stage',
        );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder logged')),
      );
    }
  }

  Future<void> _setDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || _selectedDriverId == null) return;
    await ref.read(onboardingRepositoryProvider).setDeadline(
          driverId: _selectedDriverId!,
          date: picked,
          kind: 'onboarding',
        );
    await _load();
  }

  Future<void> _uploadDocument(DocumentType type) async {
    if (_selectedDriverId == null) {
      _showError('Select a pending driver first.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    try {
      final row = await ref.read(onboardingRepositoryProvider).upsertDocument(
            driverId: _selectedDriverId!,
            docType: type,
            fileBytes: file.bytes!,
            fileName: file.name,
          );
      setState(() {
        _docFiles[type] = row.fileName ?? file.name;
        _docStatus[type] = row.status;
        _loadedDocs = [..._loadedDocs.where((d) => d.docType != type), row];
      });
    } catch (e) {
      _showError('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(pendingDriversForRegistrationProvider);

    if (_loading && _selectedDriverId != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AdminTokens.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Register company e-trike driver'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Operator provides the e-trike unit. Track hiring pipeline and compliance checklist in one place.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdminTokens.textSecondary),
          ),
          const SizedBox(height: 16),
          pendingAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Could not load applicants: $e'),
            data: (pending) {
              if (pending.isEmpty) {
                return const Text('No pending driver applicants. Drivers appear here after signing up in the driver app.');
              }
              return DropdownButtonFormField<String>(
                value: _selectedDriverId,
                decoration: const InputDecoration(
                  labelText: 'Pending driver applicant',
                  helperText: 'Select who you are onboarding',
                ),
                items: pending
                    .map(
                      (d) => DropdownMenuItem(
                        value: d.id,
                        child: Text(d.fullName.isNotEmpty ? d.fullName : d.email),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  setState(() => _selectedDriverId = id);
                  _load();
                },
              );
            },
          ),
          const SizedBox(height: 16),
          OnboardingProgressHeader(
            pipeline: _pipeline.copyWith(checklistPercent: _checklistPercent),
            checklistPercent: _checklistPercent,
            onSendReminder: _selectedDriverId == null ? null : _sendReminder,
            onSetDeadline: _selectedDriverId == null ? null : _setDeadline,
          ),
          if (_timeline.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TimelinePanel(entries: _timeline),
          ],
          const SizedBox(height: 20),
          RegistrationStepIndicator(currentStep: _step, completedSteps: _completed),
          const SizedBox(height: 24),
          _buildStepContent(),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_step > 1)
                OutlinedButton(onPressed: _prevStep, child: const Text('Back')),
              const Spacer(),
              if (_step < 7)
                FilledButton(onPressed: _nextStep, child: const Text('Continue'))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _canApprove ? _approveRegistration : null,
                      child: const Text('Approve registration'),
                    ),
                    OutlinedButton(
                      onPressed: () => _showApproveWithExceptions(),
                      child: const Text('Approve with exceptions'),
                    ),
                    OutlinedButton(
                      onPressed: () => _showMoreInfo(),
                      child: const Text('Request more info'),
                    ),
                    TextButton(
                      onPressed: () => _showReject(),
                      child: const Text('Reject application', style: TextStyle(color: AdminTokens.critical)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _canApprove {
    if (_selectedDriverId == null) return false;
    for (final t in kRequiredDriverDocuments) {
      final has = _loadedDocs.any((d) => d.docType == t && d.fileUrl != null);
      if (!has) return false;
      final st = _docStatus[t];
      if (st == DocumentStatus.rejected) return false;
    }
    return _step1Valid;
  }

  Future<void> _approveRegistration() async {
    if (_selectedDriverId == null) return;
    try {
      if (_assignedUnit != null) {
        final vehicle = _vehicles.cast<VehicleRow?>().firstWhere(
              (v) => v?.id == _assignedUnit || v?.unitNumber == _assignedUnit,
              orElse: () => null,
            );
        if (vehicle != null) {
          await ref.read(onboardingRepositoryProvider).assignVehicle(
                vehicleId: vehicle.id,
                driverId: _selectedDriverId!,
                plateNumber: vehicle.plateNumber,
              );
        }
      }
      await ref.read(onboardingRepositoryProvider).approveRegistration(
            driverId: _selectedDriverId!,
          );
      ref.invalidate(pendingDriversProvider);
      ref.invalidate(approvedDriversProvider);
      ref.invalidate(fleetOverviewProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver approved')),
        );
        context.go('/drivers/$_selectedDriverId');
      }
    } catch (e) {
      _showError('$e');
    }
  }

  void _showApproveWithExceptions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve with exceptions'),
        content: TextField(
          controller: _exceptionNotes,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Which documents are outstanding and deadline to submit?',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (_selectedDriverId == null) return;
              await ref.read(onboardingRepositoryProvider).approveRegistration(
                    driverId: _selectedDriverId!,
                    withExceptions: true,
                    notes: _exceptionNotes.text.trim(),
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Approved with exceptions')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showMoreInfo() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request more info'),
        content: TextField(
          controller: _moreInfoNotes,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'What is missing?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showError('Sent back to applicant');
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showReject() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject application'),
        content: TextField(
          controller: _rejectReason,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Reason (required)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminTokens.critical),
            onPressed: () async {
              if (_rejectReason.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              if (_selectedDriverId == null) return;
              await ref.read(onboardingRepositoryProvider).rejectRegistration(
                    driverId: _selectedDriverId!,
                    reason: _rejectReason.text.trim(),
                  );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Application rejected')),
                );
                context.go('/');
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_step) {
      1 => _StepPersonalInfo(
          firstName: _firstName,
          middleName: _middleName,
          lastName: _lastName,
          dob: _dob,
          onDobChanged: (d) => setState(() => _dob = d),
          sex: _sex,
          onSexChanged: (v) => setState(() => _sex = v),
          civilStatus: _civilStatus,
          onCivilChanged: (v) => setState(() => _civilStatus = v),
          nationality: _nationality,
          street: _street,
          barangay: _barangay,
          city: _city,
          province: _province,
          zip: _zip,
          contact: _contact,
          email: _email,
          emergencyName: _emergencyName,
          emergencyRelation: _emergencyRelation,
          emergencyPhone: _emergencyPhone,
          onUploadPhoto: () => _uploadDocument(DocumentType.profilePhoto),
          onUploadId: () => _uploadDocument(DocumentType.validId),
          photoUploaded: _docFiles.containsKey(DocumentType.profilePhoto),
          idUploaded: _docFiles.containsKey(DocumentType.validId),
        ),
      2 => _DocumentStepPanel(
          title: "Driver's license & franchise",
          subtitle:
              'SulongRide provides company-owned e-trikes. OR/CR is not required — assign a fleet unit below.',
          documents: const [
            DocumentType.pdl,
            DocumentType.ltfrbCpc,
          ],
          files: _docFiles,
          statuses: _docStatus,
          onUpload: _uploadDocument,
          extraFields: _vehicles.isEmpty
              ? null
              : DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Assigned e-trike unit',
                    helperText: 'Company unit this driver will operate',
                  ),
                  items: _vehicles
                      .map((v) => DropdownMenuItem(value: v.id, child: Text(v.displayLabel)))
                      .toList(),
                  onChanged: (v) => setState(() => _assignedUnit = v),
                ),
        ),
      3 => _DocumentStepPanel(
          title: 'Government clearances',
          documents: const [
            DocumentType.nbi,
            DocumentType.policeClearance,
            DocumentType.barangayClearance,
            DocumentType.psaBirth,
          ],
          files: _docFiles,
          statuses: _docStatus,
          onUpload: _uploadDocument,
        ),
      4 => _DocumentStepPanel(
          title: 'Health & drug test',
          documents: const [DocumentType.medicalCert, DocumentType.drugTest],
          files: _docFiles,
          statuses: _docStatus,
          onUpload: _uploadDocument,
        ),
      5 => _ContributionsStep(onUpload: _uploadDocument, files: _docFiles),
      6 => _EmploymentStep(
          employmentType: _employmentType,
          onEmploymentChanged: (v) => setState(() => _employmentType = v),
          shift: _shift,
          onShiftChanged: (v) => setState(() => _shift = v),
          assignedUnit: _assignedUnit,
          vehicles: _vehicles,
          onUnitChanged: (v) => setState(() => _assignedUnit = v),
          boundaryFee: _boundaryFee,
          perTripRate: _perTripRate,
          startDate: _startDate,
          probationEnd: _probationEnd,
          onStartDate: (d) => setState(() {
            _startDate = d;
            _probationEnd = DateTime(d.year, d.month + 6, d.day);
          }),
        ),
      _ => _ReviewStep(
          checklistPercent: _checklistPercent,
          files: _docFiles,
          statuses: _docStatus,
          onGoToStep: _goToStep,
          fullName: '${_firstName.text} ${_lastName.text}'.trim(),
        ),
    };
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.entries});

  final List<OnboardingTimelineEntry> entries;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, h:mm a');
    return AdminPanelCard(
      title: 'Reminders & deadlines',
      child: Column(
        children: entries.take(5).map((e) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              e.action.contains('reminder') ? Icons.notifications_outlined : Icons.event_outlined,
              color: AdminTokens.accent,
            ),
            title: Text(e.summary),
            subtitle: Text('${fmt.format(e.at)}${e.actorName != null ? ' · ${e.actorName}' : ''}'),
          );
        }).toList(),
      ),
    );
  }
}

class _StepPersonalInfo extends StatelessWidget {
  const _StepPersonalInfo({
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.dob,
    required this.onDobChanged,
    required this.sex,
    required this.onSexChanged,
    required this.civilStatus,
    required this.onCivilChanged,
    required this.nationality,
    required this.street,
    required this.barangay,
    required this.city,
    required this.province,
    required this.zip,
    required this.contact,
    required this.email,
    required this.emergencyName,
    required this.emergencyRelation,
    required this.emergencyPhone,
    required this.onUploadPhoto,
    required this.onUploadId,
    required this.photoUploaded,
    required this.idUploaded,
  });

  final TextEditingController firstName;
  final TextEditingController middleName;
  final TextEditingController lastName;
  final DateTime? dob;
  final ValueChanged<DateTime> onDobChanged;
  final String sex;
  final ValueChanged<String> onSexChanged;
  final String civilStatus;
  final ValueChanged<String> onCivilChanged;
  final TextEditingController nationality;
  final TextEditingController street;
  final TextEditingController barangay;
  final TextEditingController city;
  final TextEditingController province;
  final TextEditingController zip;
  final TextEditingController contact;
  final TextEditingController email;
  final TextEditingController emergencyName;
  final TextEditingController emergencyRelation;
  final TextEditingController emergencyPhone;
  final VoidCallback onUploadPhoto;
  final VoidCallback onUploadId;
  final bool photoUploaded;
  final bool idUploaded;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Step 1 — Personal information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _field('First name *', firstName, width: 180),
              _field('Middle name', middleName, width: 180),
              _field('Last name *', lastName, width: 180),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime(1995),
                firstDate: DateTime(1960),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
              );
              if (d != null) onDobChanged(d);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(dob == null ? 'Date of birth *' : DateFormat.yMMMd().format(dob!)),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: sex,
            decoration: const InputDecoration(labelText: 'Sex'),
            items: ['Male', 'Female', 'Prefer not to say']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => v == null ? null : onSexChanged(v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: civilStatus,
            decoration: const InputDecoration(labelText: 'Civil status'),
            items: ['Single', 'Married', 'Widowed', 'Separated']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => v == null ? null : onCivilChanged(v),
          ),
          const SizedBox(height: 8),
          _field('Nationality', nationality),
          const SizedBox(height: 8),
          _field('Street *', street),
          Wrap(
            spacing: 12,
            children: [
              _field('Barangay', barangay, width: 160),
              _field('City / Municipality', city, width: 180),
              _field('Province', province, width: 160),
              _field('ZIP', zip, width: 100),
            ],
          ),
          const SizedBox(height: 8),
          _field('Contact (09XXXXXXXXX) *', contact),
          _field('Email (optional)', email),
          const Divider(height: 32),
          _field('Emergency contact name', emergencyName),
          _field('Relationship', emergencyRelation),
          _field('Emergency number', emergencyPhone),
          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onUploadPhoto,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(photoUploaded ? 'Photo uploaded' : 'Profile photo'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onUploadId,
                icon: const Icon(Icons.badge_outlined),
                label: Text(idUploaded ? 'Valid ID uploaded' : 'Valid ID'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {double? width}) {
    final field = TextField(
      controller: c,
      decoration: InputDecoration(labelText: label),
    );
    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return field;
  }
}

class _DocumentStepPanel extends StatelessWidget {
  const _DocumentStepPanel({
    required this.title,
    required this.documents,
    required this.files,
    required this.statuses,
    required this.onUpload,
    this.subtitle,
    this.extraFields,
  });

  final String title;
  final String? subtitle;
  final List<DocumentType> documents;
  final Map<DocumentType, String> files;
  final Map<DocumentType, DocumentStatus> statuses;
  final void Function(DocumentType) onUpload;
  final Widget? extraFields;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(subtitle!, style: const TextStyle(color: AdminTokens.textSecondary)),
            ),
          if (extraFields != null) ...[extraFields!, const SizedBox(height: 16)],
          ...documents.map((d) => _DocumentCard(
                type: d,
                fileName: files[d],
                status: statuses[d] ?? (files.containsKey(d) ? DocumentStatus.pending : null),
                onUpload: () => onUpload(d),
              )),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.type,
    required this.onUpload,
    this.fileName,
    this.status,
  });

  final DocumentType type;
  final String? fileName;
  final DocumentStatus? status;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: AdminTokens.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(type.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (status != null) DocumentStatusBadge(status: status!),
            ],
          ),
          if (fileName != null) ...[
            const SizedBox(height: 8),
            Text(fileName!, style: const TextStyle(fontSize: 12, color: AdminTokens.textSecondary)),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onUpload,
            icon: const Icon(Icons.upload_file_outlined, size: 18),
            label: Text(fileName == null ? 'Upload PDF or JPG' : 'Replace file'),
          ),
        ],
      ),
    );
  }
}

class _ContributionsStep extends StatelessWidget {
  const _ContributionsStep({required this.onUpload, required this.files});

  final void Function(DocumentType) onUpload;
  final Map<DocumentType, String> files;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Step 5 — Government contributions',
      child: Column(
        children: [
          _govField('SSS number', 'XX-XXXXXXX-X'),
          _govField('PhilHealth number', 'XX-XXXXXXXXX-X'),
          _govField('Pag-IBIG MID', 'XXXX-XXXX-XXXX'),
          _govField('TIN (BIR)', 'XXX-XXX-XXX-XXX'),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onUpload(DocumentType.sss),
            child: Text(files.containsKey(DocumentType.sss) ? 'SSS sheet uploaded' : 'Upload SSS member data (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _govField(String label, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(decoration: InputDecoration(labelText: label, hintText: hint)),
    );
  }
}

class _EmploymentStep extends StatelessWidget {
  const _EmploymentStep({
    required this.employmentType,
    required this.onEmploymentChanged,
    required this.shift,
    required this.onShiftChanged,
    required this.assignedUnit,
    required this.vehicles,
    required this.onUnitChanged,
    required this.boundaryFee,
    required this.perTripRate,
    required this.startDate,
    required this.probationEnd,
    required this.onStartDate,
  });

  final String employmentType;
  final ValueChanged<String> onEmploymentChanged;
  final String shift;
  final ValueChanged<String> onShiftChanged;
  final String? assignedUnit;
  final List<VehicleRow> vehicles;
  final ValueChanged<String?> onUnitChanged;
  final TextEditingController boundaryFee;
  final TextEditingController perTripRate;
  final DateTime? startDate;
  final DateTime? probationEnd;
  final ValueChanged<DateTime> onStartDate;

  @override
  Widget build(BuildContext context) {
    return AdminPanelCard(
      title: 'Step 6 — Employment setup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Company assigns an e-trike unit. Only unassigned fleet units are listed.',
            style: TextStyle(color: AdminTokens.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: employmentType,
            decoration: const InputDecoration(labelText: 'Employment type'),
            items: ['Regular', 'Contractual', 'Per-trip (boundary)']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => v == null ? null : onEmploymentChanged(v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: shift,
            decoration: const InputDecoration(labelText: 'Shift schedule'),
            items: [
              'Morning (5AM–1PM)',
              'Afternoon (1PM–9PM)',
              'Night (9PM–5AM)',
              'Split',
              'Flexible',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => v == null ? null : onShiftChanged(v),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: assignedUnit,
            decoration: const InputDecoration(labelText: 'Assigned company e-trike'),
            items: vehicles
                .map((v) => DropdownMenuItem(value: v.id, child: Text('${v.displayLabel} (available)')))
                .toList(),
            onChanged: onUnitChanged,
          ),
          const SizedBox(height: 8),
          TextField(controller: boundaryFee, decoration: const InputDecoration(labelText: 'Daily boundary fee (₱)')),
          TextField(controller: perTripRate, decoration: const InputDecoration(labelText: 'Per-trip rate (₱)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) onStartDate(d);
            },
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(startDate == null ? 'Start date' : 'Start: ${DateFormat.yMMMd().format(startDate!)}'),
          ),
          if (probationEnd != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Probation ends: ${DateFormat.yMMMd().format(probationEnd!)}',
                style: const TextStyle(color: AdminTokens.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.checklistPercent,
    required this.files,
    required this.statuses,
    required this.onGoToStep,
    required this.fullName,
  });

  final int checklistPercent;
  final Map<DocumentType, String> files;
  final Map<DocumentType, DocumentStatus> statuses;
  final void Function(int step) onGoToStep;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    final missing = kRequiredDriverDocuments.where((d) => !files.containsKey(d)).toList();

    return AdminPanelCard(
      title: 'Step 7 — Review & submit',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fullName.isNotEmpty) Text(fullName, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SegmentedProgressBar(percent: checklistPercent),
          const SizedBox(height: 20),
          ExpansionTile(title: const Text('Documents'), children: [
            for (final d in kRequiredDriverDocuments)
              ListTile(
                title: Text(d.label),
                trailing: DocumentStatusBadge(
                  status: statuses[d] ??
                      (files.containsKey(d) ? DocumentStatus.pending : DocumentStatus.pending),
                ),
                subtitle: files[d] != null ? Text(files[d]!) : const Text('Missing', style: TextStyle(color: AdminTokens.critical)),
              ),
          ]),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Missing required documents:', style: TextStyle(color: AdminTokens.critical)),
            ...missing.map(
              (d) => TextButton(
                onPressed: () => onGoToStep(d.wizardStep),
                child: Text('Go back — ${d.label}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
