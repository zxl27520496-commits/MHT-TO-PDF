import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../models/conversion_item.dart';
import '../services/mht_converter_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<ConversionItem> _items = [];
  bool _isConverting = false;
  String _outputDir = '';

  @override
  void initState() {
    super.initState();
    _initOutputDir();
  }

  Future<void> _initOutputDir() async {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
    final outputDir = Directory('${dir.path}/MHT转PDF输出');
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    setState(() {
      _outputDir = outputDir.path;
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mht', 'mhtml'],
      allowMultiple: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (final file in result.files) {
          if (file.path != null) {
            final exists = _items.any((item) => item.filePath == file.path);
            if (!exists) {
              _items.add(ConversionItem(
                filePath: file.path!,
                fileName: file.name,
              ));
            }
          }
        }
      });
    }
  }

  Future<void> _pickOutputDir() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() {
        _outputDir = result;
      });
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _clearAll() {
    if (_items.isEmpty || _isConverting) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _items.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _startConversion() async {
    if (_items.isEmpty || _isConverting) return;

    setState(() {
      _isConverting = true;
      for (final item in _items) {
        if (item.status == ConversionStatus.failed) {
          item.status = ConversionStatus.pending;
          item.errorMessage = null;
        }
      }
    });

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.status == ConversionStatus.success) continue;

      setState(() {
        item.status = ConversionStatus.converting;
      });

      try {
        final outputPath = '$_outputDir/${_getOutputFileName(item.fileName)}';
        final result = await MhtConverterService.convertMhtToPdf(
          mhtPath: item.filePath,
          outputPath: outputPath,
        );
        setState(() {
          item.status = ConversionStatus.success;
          item.outputPath = result;
        });
      } catch (e) {
        setState(() {
          item.status = ConversionStatus.failed;
          item.errorMessage = e.toString();
        });
      }
    }

    setState(() {
      _isConverting = false;
    });

    final successCount = _items.where((i) => i.status == ConversionStatus.success).length;
    final failCount = _items.where((i) => i.status == ConversionStatus.failed).length;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('转换完成！成功 $successCount 个，失败 $failCount 个'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getOutputFileName(String inputName) {
    final name = inputName.replaceAll(
      RegExp(r'\.(mht|mhtml)$', caseSensitive: false),
      '',
    );
    return '$name.pdf';
  }

  Future<void> _openPdf(String? path) async {
    if (path == null || !File(path).existsSync()) return;
    await OpenFilex.open(path);
  }

  Future<void> _openOutputDir() async {
    if (_outputDir.isEmpty) return;
    await OpenFilex.open(_outputDir);
  }

  @override
  Widget build(BuildContext context) {
    final successCount = _items.where((i) => i.status == ConversionStatus.success).length;
    final progress = _items.isEmpty ? 0.0 : successCount / _items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MHT 转 PDF'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              onPressed: _isConverting ? null : _clearAll,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: '清空列表',
            ),
        ],
      ),
      body: Column(
        children: [
          _buildOutputDirBar(),
          if (_isConverting) _buildProgressBar(progress),
          Expanded(
            child: _items.isEmpty ? _buildEmptyState() : _buildFileList(),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildOutputDirBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          const Icon(Icons.folder_outlined, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '输出: ${_outputDir.split('/').last}',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _isConverting ? null : _pickOutputDir,
            child: const Text('更改'),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 18),
            onPressed: _openOutputDir,
            tooltip: '打开输出文件夹',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '正在转换... ${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.picture_as_pdf_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无MHT文件',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮添加文件开始转换',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _buildFileItem(_items[index], index);
      },
    );
  }

  Widget _buildFileItem(ConversionItem item, int index) {
    Color statusColor;
    IconData statusIcon;

    switch (item.status) {
      case ConversionStatus.pending:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
      case ConversionStatus.converting:
        statusColor = Colors.blue;
        statusIcon = Icons.autorenew;
        break;
      case ConversionStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case ConversionStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                item.status == ConversionStatus.converting
                    ? Icons.picture_as_pdf
                    : Icons.description,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.fileName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        item.status == ConversionStatus.failed
                            ? '${item.statusText}: ${item.errorMessage ?? ''}'
                            : item.statusText,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (item.status == ConversionStatus.success)
              IconButton(
                icon: const Icon(Icons.visibility_outlined, size: 20),
                onPressed: () => _openPdf(item.outputPath),
                tooltip: '查看PDF',
              )
            else if (!_isConverting)
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => _removeItem(index),
                tooltip: '移除',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isConverting ? null : _pickFiles,
                icon: const Icon(Icons.add),
                label: const Text('添加文件'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _items.isEmpty || _isConverting ? null : _startConversion,
                icon: Icon(_isConverting ? Icons.autorenew : Icons.play_arrow),
                label: Text(_isConverting ? '转换中...' : '开始转换'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
