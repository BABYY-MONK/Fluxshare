import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/download_manager.dart';
import '../theme/app_theme.dart';

class DownloadManagerScreen extends StatefulWidget {
  const DownloadManagerScreen({super.key});

  @override
  State<DownloadManagerScreen> createState() => _DownloadManagerScreenState();
}

class _DownloadManagerScreenState extends State<DownloadManagerScreen> {
  final _manager = DownloadManager.instance;
  final _url = TextEditingController();
  StreamSubscription<List<ManagedDownload>>? _subscription;
  List<ManagedDownload> _items = const [];
  bool _ready = false;
  bool _adding = false;
  String? _directory;

  @override
  void initState() {
    super.initState();
    _items = _manager.items;
    _subscription = _manager.updates.listen((items) {
      if (mounted) setState(() => _items = items);
    });
    _manager.initialize().then((_) {
      if (mounted) {
        setState(() {
          _items = _manager.items;
          _ready = true;
        });
      }
    });
  }

  Future<void> _add() async {
    final url = _url.text.trim();
    if (url.isEmpty || _adding) return;
    setState(() => _adding = true);
    try {
      await _manager.add(url, destination: _directory);
      _url.clear();
    } catch (error) {
      _message(error
          .toString()
          .replaceFirst('Bad state: ', '')
          .replaceFirst('FormatException: ', ''));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _chooseDirectory() async {
    final selected = await FilePicker.platform
        .getDirectoryPath(dialogTitle: 'Choose download folder');
    if (selected != null && mounted) setState(() => _directory = selected);
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  String _bytes(int value) {
    if (value < 1024) return '$value B';
    if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    if (value < 1024 * 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            Icon(Icons.download_for_offline_outlined,
                color: AppColors.electric),
            SizedBox(width: 8),
            Text('Download manager'),
          ]),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(32),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Windows mode · downloads stay on this device'),
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add a download',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          const Text(
                              'Paste a direct HTTPS file link. FluxShare checks the host and saves transfer data locally for resume.'),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: _url,
                                keyboardType: TextInputType.url,
                                onSubmitted: (_) => _add(),
                                decoration: const InputDecoration(
                                  labelText: 'Download URL',
                                  hintText: 'https://example.com/archive.zip',
                                  prefixIcon: Icon(Icons.link),
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: _ready && !_adding ? _add : null,
                              icon: _adding
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.add),
                              label: Text(_adding ? 'Checking…' : 'Add'),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _chooseDirectory,
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('Choose folder'),
                                ),
                                SelectableText(
                                    _directory ?? _defaultFolderLabel,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ]),
                          const SizedBox(height: 8),
                          Text(
                              'HTTPS only. Local network addresses and URLs containing credentials are blocked. Browser capture and FTP are not enabled.',
                              style: Theme.of(context).textTheme.bodySmall),
                        ]),
                  ),
                ),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                      child: Text('Queue',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700))),
                  Text(
                      '${_items.length} ${_items.length == 1 ? 'task' : 'tasks'}'),
                ]),
                const SizedBox(height: 10),
                if (!_ready)
                  const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator()))
                else if (_items.isEmpty)
                  const _EmptyQueue()
                else
                  for (final item in _items) _downloadCard(item),
              ],
            ),
          ),
        ),
      );

  String get _defaultFolderLabel => 'Downloads folder';

  Widget _downloadCard(ManagedDownload item) {
    final active = item.status == ManagedDownloadStatus.downloading ||
        item.status == ManagedDownloadStatus.merging;
    final status = switch (item.status) {
      ManagedDownloadStatus.queued => 'Queued',
      ManagedDownloadStatus.downloading => 'Downloading',
      ManagedDownloadStatus.paused => 'Paused',
      ManagedDownloadStatus.merging => 'Finishing file…',
      ManagedDownloadStatus.done => 'Complete',
      ManagedDownloadStatus.error => 'Needs attention',
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.insert_drive_file_outlined,
                color: AppColors.electric),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(status, style: Theme.of(context).textTheme.bodySmall),
                ])),
            if (active)
              IconButton(
                  tooltip: 'Pause',
                  onPressed: () => _manager.pause(item.id),
                  icon: const Icon(Icons.pause_circle_outline))
            else if (item.status != ManagedDownloadStatus.done)
              IconButton(
                  tooltip: 'Resume',
                  onPressed: () => _manager.resume(item.id),
                  icon: const Icon(Icons.play_circle_outline)),
            if (item.status == ManagedDownloadStatus.done &&
                item.resultPath != null)
              IconButton(
                  tooltip: 'Copy saved path',
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: item.resultPath!));
                    _message('Saved path copied.');
                  },
                  icon: const Icon(Icons.copy)),
            IconButton(
                tooltip: 'Remove from queue',
                onPressed: () => _manager.remove(item.id),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 12),
          LinearProgressIndicator(
              value: item.totalBytes > 0 ? item.progress : (active ? null : 0)),
          const SizedBox(height: 6),
          Text(
              item.totalBytes > 0
                  ? '${_bytes(item.receivedBytes)} of ${_bytes(item.totalBytes)} · ${(item.progress * 100).toStringAsFixed(0)}%'
                  : '${_bytes(item.receivedBytes)} received',
              style: Theme.of(context).textTheme.bodySmall),
          if (item.error != null) ...[
            const SizedBox(height: 8),
            Text(item.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (item.resultPath != null) ...[
            const SizedBox(height: 6),
            SelectableText(item.resultPath!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            const Icon(Icons.download_outlined,
                size: 42, color: AppColors.muted),
            const SizedBox(height: 8),
            Text('Your download queue is empty',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('Add a direct HTTPS link to start a local download.'),
          ]),
        ),
      );
}
