import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class MhtConverterService {
  static const MethodChannel _channel =
      MethodChannel('com.example.mht_to_pdf/converter');

  static Future<String> convertMhtToPdf({
    required String mhtPath,
    String? outputPath,
  }) async {
    if (outputPath == null || outputPath.isEmpty) {
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${_getBaseName(mhtPath)}.pdf';
      outputPath = '${dir.path}/$fileName';
    }

    final result = await _channel.invokeMethod<String>(
      'convertMhtToPdf',
      {
        'mhtPath': mhtPath,
        'outputPath': outputPath,
      },
    );

    if (result == null) {
      throw Exception('转换失败：返回结果为空');
    }

    return result;
  }

  static String _getBaseName(String path) {
    final name = path.split(Platform.pathSeparator).last;
    return name.replaceAll(RegExp(r'\.(mht|mhtml)$', caseSensitive: false), '');
  }
}
