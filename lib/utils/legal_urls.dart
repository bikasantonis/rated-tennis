import 'package:url_launcher/url_launcher.dart';

/// Central store for legal document URLs.
/// Update these once GitHub Pages is configured for the repo.
abstract final class LegalUrls {
  static const privacyPolicy =
      'https://bikasantonis.github.io/rated-tennis/privacy-policy';
  static const termsOfUse =
      'https://bikasantonis.github.io/rated-tennis/terms';

  static Future<void> open(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
