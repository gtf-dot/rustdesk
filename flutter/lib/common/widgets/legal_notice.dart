import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../common.dart';
import '../../models/platform_model.dart';

// Notices required by the GNU AGPL v3.0 for this modified version of RustDesk:
// original and modification copyrights (section 5a), the license, no-warranty
// statement and how to view the license (section 0 "Appropriate Legal Notices",
// 5d), and where to get the corresponding source (sections 6 and 13).
// The full license text ships with every build as assets/LICENCE.
const kUpstreamCopyrightHolder = 'Purslane Tech Pte. Ltd.';
const kModificationsCopyrightHolder = 'GRI SAS';
const kSourceCodeUrl = 'https://github.com/gtf-dot/rustdesk';
const kLicenseUrl = 'https://www.gnu.org/licenses/agpl-3.0.html';

class LegalNoticeBox extends StatelessWidget {
  final String license;

  /// Short layout that fits the fixed 400x300 main window without scrolling.
  final bool compact;

  /// Shown next to the app name in the compact layout.
  final String version;

  /// Defaults to the app name reported by the Rust core.
  final String? appName;

  const LegalNoticeBox(
      {Key? key,
      this.license = '',
      this.compact = false,
      this.version = '',
      this.appName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final name = appName ?? bind.mainGetAppNameSync();
    final white = TextStyle(color: Colors.white, fontSize: compact ? 12 : null);
    final link = white.copyWith(decoration: TextDecoration.underline);
    Widget linkText(String text, String url) => InkWell(
          onTap: () => launchUrlString(url),
          child: Text(text, style: link),
        );
    final copyrights = <Widget>[
      Text('Copyright © $year $kUpstreamCopyrightHolder', style: white),
      Text('Copyright © $year $kModificationsCopyrightHolder', style: white),
      if (license.isNotEmpty) Text(license, style: white),
    ];

    if (compact) {
      return Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Color(0xFF2c8cff)),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(version.isEmpty ? name : '$name $version',
                style: white.copyWith(fontWeight: FontWeight.w700)),
            ...copyrights,
            Text(
              'Modified version of RustDesk. Free software: you may '
              'redistribute it under the GNU AGPL v3.0. '
              'ABSOLUTELY NO WARRANTY.',
              style: white,
            ).marginOnly(top: 4),
            Wrap(spacing: 16, children: [
              linkText('Source code', kSourceCodeUrl),
              linkText('License', kLicenseUrl),
            ]).marginOnly(top: 4),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Color(0xFF2c8cff)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...copyrights,
          Text(
            '$name is a modified version of RustDesk, changed by '
            '$kModificationsCopyrightHolder. It is free software licensed '
            'under the GNU Affero General Public License v3.0 and comes with '
            'ABSOLUTELY NO WARRANTY. You may redistribute and modify it under '
            'the terms of that license.',
            style: white,
          ).marginOnly(top: 8),
          linkText('Source code: $kSourceCodeUrl', kSourceCodeUrl)
              .marginOnly(top: 4),
          linkText('License: GNU AGPL v3.0', kLicenseUrl).marginOnly(top: 4),
          Text(
            translate('Slogan_tip'),
            style: white.copyWith(fontWeight: FontWeight.w800),
          ).marginOnly(top: 8),
        ],
      ),
    );
  }
}
