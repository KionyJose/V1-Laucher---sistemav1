import 'dart:io';
import 'dart:isolate';

import 'window_native.dart';
export 'window_native.dart' show OpenAppWindow;

class WindowListService {
  Future<List<OpenAppWindow>> list() async {
    if (!Platform.isWindows) return [];
    return Isolate.run(enumerateOpenWindows);
  }
}
