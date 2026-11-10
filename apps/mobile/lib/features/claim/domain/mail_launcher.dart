/// Opens the user's mail app (port, so the claim flow is testable).
abstract class MailLauncher {
  /// Returns whether a mail app took the `mailto:` [uri].
  Future<bool> open(Uri uri);
}

/// Builds a `mailto:` URI with percent-encoded (never `+`) spaces, which is
/// what mail apps expect. [to] may be empty.
Uri buildMailto({
  required String to,
  required String subject,
  required String body,
}) => Uri.parse(
  'mailto:${to.trim()}'
  '?subject=${Uri.encodeComponent(subject)}'
  '&body=${Uri.encodeComponent(body)}',
);
