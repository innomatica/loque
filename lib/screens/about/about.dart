import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../settings/constants.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String? _getStoreUrl() {
    if (Platform.isAndroid) {
      return urlGooglePlay;
    } else if (Platform.isIOS) {
      return urlAppStore;
    }
    return urlHomePage;
  }

  Widget _buildBody() {
    return ListView(
      children: [
        ListTile(
          title: Text(
            'Version',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text(appVersion),
        ),
        ListTile(
          title: Text(
            'Questions and Answers',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text('How to Use This App'),
          onTap: () {
            launchUrl(Uri.parse(urlInstruction),
                mode: LaunchMode.externalApplication);
          },
        ),
        ListTile(
          title: Text(
            'Visit Our Store',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text('Review Apps, Report Bugs, Share Your Thoughts'),
          onTap: () {
            final url = _getStoreUrl();
            if (url != null) {
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
          },
        ),
        ListTile(
          title: Text(
            'Recommend to Others',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text('Show QR Code'),
          onTap: () {
            final url = _getStoreUrl();
            if (url != null) {
              showDialog(
                context: context,
                builder: (context) {
                  return SimpleDialog(
                    title: Center(
                      child: Text(
                        'Visit Our Store',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: Image.asset(playStoreUrlQrCode),
                      )
                    ],
                  );
                },
              );
            }
          },
        ),
        ListTile(
          title: Text(
            'Contact Us',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text(urlHomePage),
          onTap: () {
            launchUrl(Uri.parse(urlHomePage),
                mode: LaunchMode.externalApplication);
          },
        ),
        ListTile(
          title: Text(
            'App Icons',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle:
              const Text("Microphone icons created by Freepik - Flaticon"),
          onTap: () {
            launchUrl(Uri.parse(urlAppIconSource));
          },
        ),
        ListTile(
          title: Text(
            'Store Background Image',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text("Photo by dlxmedia.hu from Pexels"),
          onTap: () {
            launchUrl(Uri.parse(urlStoreImageSource));
          },
        ),
        ListTile(
          title: Text(
            'Disclaimer',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text(
              'The Company assumes no responsibility for errors or omissions '
              'in the contents of the Service. (tap for the full text).'),
          onTap: () {
            launchUrl(Uri.parse(urlDisclaimer));
          },
        ),
        // Privacy
        ListTile(
          title: Text(
            'Privacy Policy',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          subtitle: const Text('We do not collect any Persional Data. '
              'We do not collect any Usage Data (tap for the full text).'),
          onTap: () {
            launchUrl(Uri.parse(urlPrivacyPolicy));
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: const Text('About'),
      ),
      body: _buildBody(),
    );
  }
}
