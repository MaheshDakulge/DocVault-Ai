/// All FastAPI backend endpoint paths for DocsVault AI
class Endpoints {
  Endpoints._();

  // ── Auth ────────────────────────────────────────────────────────────────────
  static const String login         = '/auth/login';
  static const String logout        = '/auth/logout';
  static const String refreshToken  = '/auth/refresh';
  static const String profile       = '/auth/profile';

  // ── Document Scan ───────────────────────────────────────────────────────────
  static const String scan          = '/scan';
  static const String scanBatch     = '/scan/batch';

  // ── AI Assistant ────────────────────────────────────────────────────────────
  static const String assistantChat        = '/assistant/chat';
  static const String assistantEligibility = '/assistant/eligibility';

  // ── Sync ────────────────────────────────────────────────────────────────────
  static const String syncDocuments  = '/sync/documents';
  static const String syncFields     = '/sync/fields';
  static const String syncFiles      = '/sync/files';

  // ── Sharing ─────────────────────────────────────────────────────────────────
  static const String createShareLink  = '/share/create';
  static const String revokeShareLink  = '/share/revoke';
  static const String resolveShareLink = '/share/resolve';

  // ── Schemes ─────────────────────────────────────────────────────────────────
  static const String schemes        = '/schemes';
  static const String schemeById     = '/schemes/{id}';
}
