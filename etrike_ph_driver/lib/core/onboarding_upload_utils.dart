/// User-friendly errors when Supabase storage / RLS blocks onboarding uploads.
String formatOnboardingUploadError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('driver_hiring_pipeline') ||
      message.contains('driver_documents') ||
      message.contains('driver_registration_drafts')) {
    return 'Onboarding permissions are not set up on the server yet. '
        'Ask your operator to run fix_driver_onboarding_complete.sql in Supabase SQL Editor.';
  }
  if (message.contains('row-level security') ||
      message.contains('42501') ||
      message.contains('permission denied')) {
    return 'Server blocked this action. Run fix_driver_onboarding_complete.sql in Supabase SQL Editor.';
  }
  if (message.contains('bucket not found') ||
      message.contains('storage/object-not-found') ||
      message.contains('404')) {
    return 'Document storage is not set up. Run fix_driver_onboarding_complete.sql in Supabase SQL Editor.';
  }
  if (message.contains('payload too large') || message.contains('413')) {
    return 'File is too large. Try a smaller photo or compress the PDF.';
  }
  if (message.contains('not signed in')) {
    return 'Session expired. Sign in again and retry the upload.';
  }
  return error.toString().replaceFirst('Exception: ', '').replaceFirst('StateError: ', '');
}

String sanitizeUploadFileName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'upload.jpg';
  return trimmed.replaceAll(RegExp(r'[^\w.\-]+'), '_');
}
