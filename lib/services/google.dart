import 'package:xml/xml.dart';

import '../helpers/logger.dart';
import '../models/google_opml.dart';

Future<List<GoogleOpml>> parseGooglePodcastOpml(String xmlString) async {
  // logDebug('google opml: $xmlString');
  final result = <GoogleOpml>[];
  String? xmlUrl;
  String? type;
  String? text;
  try {
    final xmlDoc = XmlDocument.parse(xmlString);
    final outlines = xmlDoc.findAllElements('outline');
    for (final outline in outlines) {
      if (outline.attributes.length > 1) {
        for (final attribute in outline.attributes) {
          logDebug('name:${attribute.name.local}, value: ${attribute.value}');
          if (attribute.name.local == 'xmlUrl') {
            xmlUrl = attribute.value;
          } else if (attribute.name.local == 'type') {
            type = attribute.value;
          } else if (attribute.name.local == 'text') {
            text = attribute.value;
          }
        }
        result.add(GoogleOpml(xmlUrl, type, text));
      }
    }
  } catch (e) {
    logError(e.toString());
  }
  return result;
}
