import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../logic/search.dart';
import '../../services/sharedprefs.dart';

class Browser extends StatefulWidget {
  final String keyword;
  const Browser(this.keyword, {super.key});

  @override
  State<Browser> createState() => _BrowserState();
}

class _BrowserState extends State<Browser> {
  late final WebViewController _controller;
  late final SearchLogic search;

  @override
  void initState() {
    super.initState();
    // https://stackoverflow.com/questions/49457717/flutter-get-context-in-initstate-method
    Future.delayed(Duration.zero, () {
      search = context.read<SearchLogic>();
    });

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          // onProgress: (int progress) {},
          // onPageStarted: (String url) async {},
          // onPageFinished: (String url) {},
          // onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) async {
            final flag = await search.getChannelDataFromRss(request.url);
            if (flag) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    content: Text(
                      'New podcast channel found',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
          // Uri.parse('https://duckduckgo.com/?q=${widget.keyword}+podcast+rss'));
          Uri.parse(SharedPrefsService.getSeachEngineUrl(widget.keyword)));
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 18.0,
      fontWeight: FontWeight.w600,
      // color: Theme.of(context).colorScheme.primary,
    );
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return Future.value(false);
        } else {
          return Future.value(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Text('Find', style: titleStyle),
              const SizedBox(width: 8.0),
              Icon(Icons.rss_feed_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8.0),
              const Text('Page and Subscribe', style: titleStyle),
            ],
          ),
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
