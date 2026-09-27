import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const privacyPolicyUrl = 'https://supercampus.ai/privacy';
const termsUrl = 'https://supercampus.ai/terms';
const contactSupportUrl = 'https://supercampus.ai/contact';
const supportEmail = 'dev@supercampus.ai';

/// Opens [url] outside the app. `canLaunchUrl` is deliberately not used as a
/// gate: it reports false in several mobile browsers and installed web apps
/// even though the launch itself works. A snackbar explains a real failure.
Future<void> openExternalUrl(
  BuildContext context,
  String url, {
  String? failureMessage,
}) async {
  final uri = Uri.parse(url);
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(
      uri,
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: uri.scheme == 'mailto' ? null : '_blank',
    );
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(failureMessage ?? 'Couldn’t open ${uri.host}${uri.path}'),
      ),
    );
  }
}

Future<void> emailSupport(BuildContext context, {String? subject}) =>
    openExternalUrl(
      context,
      Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: subject == null
            ? null
            : 'subject=${Uri.encodeComponent(subject)}',
      ).toString(),
      failureMessage: 'Couldn’t open your email app. Write to $supportEmail.',
    );
