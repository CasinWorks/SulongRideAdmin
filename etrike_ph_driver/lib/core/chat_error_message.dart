String formatChatSetupError(Object error) {
  final message = error.toString();
  if (message.contains('PGRST205') ||
      message.contains("table 'public.messages'")) {
    return 'Chat is not set up yet. In Supabase → SQL Editor, run '
        'supabase/fix_messages_table.sql, wait ~30 seconds, then reopen chat.';
  }
  return message;
}
