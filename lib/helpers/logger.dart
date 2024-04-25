import 'package:flutter/foundation.dart';

void logDebug(String text) =>
    kDebugMode ? debugPrint('\x1B[32m$text\x1B[0m') : () => {};
void logWarn(String text) => debugPrint('\x1B[33m$text\x1B[0m');
void logError(String text) => debugPrint('\x1B[31m$text\x1B[0m');
