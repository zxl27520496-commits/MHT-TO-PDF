enum ConversionStatus {
  pending,
  converting,
  success,
  failed,
}

class ConversionItem {
  final String filePath;
  final String fileName;
  ConversionStatus status;
  String? outputPath;
  String? errorMessage;

  ConversionItem({
    required this.filePath,
    required this.fileName,
    this.status = ConversionStatus.pending,
    this.outputPath,
    this.errorMessage,
  });

  String get statusText {
    switch (status) {
      case ConversionStatus.pending:
        return '等待转换';
      case ConversionStatus.converting:
        return '转换中...';
      case ConversionStatus.success:
        return '转换成功';
      case ConversionStatus.failed:
        return '转换失败';
    }
  }
}
