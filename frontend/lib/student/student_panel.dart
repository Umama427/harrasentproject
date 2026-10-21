import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api.dart';
import '../download_helper.dart';
import '../theme.dart';
import '../widgets.dart';

class StudentPanel extends StatelessWidget {
  const StudentPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelScaffold(
      title: 'Student',
      tabs: [
        ('My Complaints', Icons.list_alt_outlined, _MyComplaintsTab()),
        ('New Complaint', Icons.add_circle_outline, _NewComplaintTab()),
        ('Notifications', Icons.notifications_outlined, _NotificationsTab()),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------------

String _idOf(Map obj) {
  final v = obj['_id'] ?? obj['id'];
  return v?.toString() ?? '';
}

String _fileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ---------------------------------------------------------------------------
// My Complaints
// ---------------------------------------------------------------------------

class _MyComplaintsTab extends StatelessWidget {
  const _MyComplaintsTab();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      fetch: () => Api.list('/student/complaints'),
      builder: (context, complaints, reload) {
        return Body([
          sectionTitle('My Complaints'),
          if (complaints.isEmpty)
            const EmptyState(
              Icons.list_alt_outlined,
              'You have not filed any complaints yet.\nUse "New Complaint" to submit one.',
            )
          else
            for (final c in complaints)
              _ComplaintCard(c: c as Map, onReturn: reload),
        ]);
      },
    );
  }
}

class _ComplaintCard extends StatelessWidget {
  final Map c;
  final VoidCallback onReturn;
  const _ComplaintCard({required this.c, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final id = _idOf(c);
    final ref = c['referenceNo']?.toString() ?? id;
    final status = c['status']?.toString() ?? 'Unknown';
    final category = c['category'] is Map
        ? (c['category']['name']?.toString() ?? '')
        : (c['category']?.toString() ?? '');
    final created = fmt(c['createdAt']);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StudentComplaintDetail(id: id)),
        );
        onReturn();
      },
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref,
                    style: const TextStyle(
                      color: brightText,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(category, style: const TextStyle(color: muted, fontSize: 13)),
                  if (created.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(created, style: const TextStyle(color: muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
            StatusChip(status),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: muted),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Complaint detail (its own screen, pushed from the list)
// ---------------------------------------------------------------------------

class StudentComplaintDetail extends StatefulWidget {
  final String id;
  const StudentComplaintDetail({super.key, required this.id});

  @override
  State<StudentComplaintDetail> createState() => _StudentComplaintDetailState();
}

class _StudentComplaintDetailState extends State<StudentComplaintDetail> {
  Map<String, dynamic>? _complaint;
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await Api.obj('/student/complaints/${widget.id}');
      setState(() {
        _complaint = c;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _download(String evidenceId, String name) async {
    try {
      final bytes = await Api.downloadBytes('/evidence/$evidenceId/download');
      saveFile(bytes, name);
    } catch (e) {
      if (!mounted) return;
      snack(context, 'Download failed: $e');
    }
  }

  Future<void> _attachFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) {
        print('[FilePicker] No file selected.');
        return;
      }

      setState(() => _uploading = true);
      int uploaded = 0;
      int failed = 0;

      for (final f in result.files) {
        if (f.bytes == null) {
          failed++;
          continue;
        }
        try {
          await Api.upload('/student/complaints/${widget.id}/evidence', f.bytes!, f.name);
          uploaded++;
        } catch (e) {
          failed++;
          print('[FilePicker] Upload error for ${f.name}: $e');
        }
      }

      setState(() => _uploading = false);
      await _load();

      if (!mounted) return;
      snack(context, 'Uploaded: $uploaded, Failed: $failed');
    } catch (e) {
      setState(() => _uploading = false);
      print('[FilePicker] ERROR: $e');
      if (!mounted) return;
      snack(context, 'Could not open file picker: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: teal)));
    }

    if (_error != null || _complaint == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complaint')),
        body: Center(child: Text('Failed to load: $_error')),
      );
    }

    final c = _complaint!;
    final ref = c['referenceNo']?.toString() ?? widget.id;
    final status = c['status']?.toString() ?? 'Unknown';
    final category = c['category'] is Map
        ? (c['category']['name']?.toString() ?? '')
        : (c['category']?.toString() ?? '');
    final description = c['description']?.toString() ?? '';
    final evidence = (c['evidence'] as List?) ?? [];
    final history = (c['history'] as List?) ?? (c['statusHistory'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: Text(ref)),
      body: Body([
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Text('Status:  ', style: TextStyle(color: muted)), StatusChip(status)]),
              const SizedBox(height: 12),
              const Text('Category', style: TextStyle(color: muted, fontSize: 12)),
              Text(category, style: const TextStyle(color: brightText, fontSize: 15)),
              const SizedBox(height: 12),
              const Text('Description', style: TextStyle(color: muted, fontSize: 12)),
              Text(description, style: const TextStyle(color: brightText, fontSize: 14, height: 1.5)),
            ],
          ),
        ),
        sectionTitle('Evidence'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (evidence.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text('No evidence attached yet.', style: TextStyle(color: muted)),
                )
              else
                ...evidence.map((e) {
                  final ev = e as Map;
                  final evId = _idOf(ev);
                  final name = ev['originalName']?.toString() ?? ev['filename']?.toString() ?? 'file';
                  final size = ev['size'] is int ? ev['size'] as int : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file_outlined, color: teal),
                    title: Text(name, style: const TextStyle(color: brightText)),
                    subtitle: size != null ? Text(_fileSize(size), style: const TextStyle(color: muted)) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.download_outlined, color: teal),
                      tooltip: 'Download',
                      onPressed: () => _download(evId, name),
                    ),
                  );
                }),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _attachFile,
                icon: _uploading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: teal))
                    : const Icon(Icons.attach_file),
                label: Text(_uploading ? 'Uploading...' : 'Choose file(s) from my computer'),
              ),
            ],
          ),
        ),
        if (history.isNotEmpty) ...[
          sectionTitle('History'),
          Timeline(history),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// New complaint form
// ---------------------------------------------------------------------------

class _NewComplaintTab extends StatefulWidget {
  const _NewComplaintTab();

  @override
  State<_NewComplaintTab> createState() => _NewComplaintTabState();
}

class _NewComplaintTabState extends State<_NewComplaintTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();

  List<dynamic> _categories = [];
  String? _selectedCategoryId;
  bool _loadingCategories = true;
  bool _submitting = false;

  final List<PlatformFile> _attachments = [];

  static const _fallbackCategories = [
    'Verbal Harassment',
    'Sexual Harassment',
    'Cyber Harassment',
    'Discrimination',
    'Bullying',
    'Physical Harassment',
    'Stalking',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await Api.list('/public/categories');
      setState(() {
        _categories = list;
        _loadingCategories = false;
      });
    } catch (e) {
      print('[Categories] Failed to load from /public/categories: $e');
      setState(() {
        _categories = _fallbackCategories.map((name) => {'_id': name, 'name': name}).toList();
        _loadingCategories = false;
      });
    }
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(withData: true, allowMultiple: true);
      if (result == null || result.files.isEmpty) {
        print('[FilePicker] No file selected.');
        return;
      }
      setState(() => _attachments.addAll(result.files));
    } catch (e) {
      print('[FilePicker] ERROR: $e');
      if (!mounted) return;
      snack(context, 'Could not open file picker: $e');
    }
  }

  void _removeFile(int index) {
    setState(() => _attachments.removeAt(index));
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      snack(context, 'Please select a category.');
      return;
    }

    setState(() => _submitting = true);

    try {
      // Step 1: create the complaint (this creates it as a Draft).
      final created = await Api.post('/student/complaints', {
        'title': _titleCtrl.text.trim(),
        'categoryId': _selectedCategoryId,
        'description': _descriptionCtrl.text.trim(),
      });

      final data = (created['data'] is Map) ? created['data'] as Map : created;
      final newId = _idOf(data);

      if (newId.isEmpty) {
        throw Exception('Server did not return a complaint id.');
      }

      // Step 2: upload any attached evidence files to the new complaint.
      int uploaded = 0;
      int failed = 0;

      for (final f in _attachments) {
        if (f.bytes == null) {
          failed++;
          continue;
        }
        try {
          await Api.upload('/student/complaints/$newId/evidence', f.bytes!, f.name);
          uploaded++;
        } catch (e) {
          failed++;
          print('[FilePicker] Upload error for ${f.name}: $e');
        }
      }

      // Step 3: actually submit the complaint so it leaves Draft status
      // and becomes visible to Admin / Committee.
      try {
        await Api.post('/student/complaints/$newId/submit', {});
      } catch (e) {
        print('[Submit] Failed to submit complaint $newId: $e');
        setState(() => _submitting = false);
        if (!mounted) return;
        snack(context, 'Complaint was created but could not be submitted: $e');
        return;
      }

      setState(() => _submitting = false);
      if (!mounted) return;

      final message = StringBuffer('Complaint submitted successfully.');
      if (_attachments.isNotEmpty) {
        message.write('\nEvidence uploaded: $uploaded, failed: $failed.');
      }

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Success'),
          content: Text(message.toString()),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
          ],
        ),
      );

      _titleCtrl.clear();
      _descriptionCtrl.clear();
      setState(() {
        _selectedCategoryId = null;
        _attachments.clear();
      });
    } catch (e) {
      setState(() => _submitting = false);
      if (!mounted) return;
      snack(context, 'Failed to submit complaint: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Body([
      sectionTitle('New Complaint'),
      Form(
        key: _formKey,
        child: Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return 'Please provide a short title.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _loadingCategories
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: LinearProgressIndicator(color: teal),
                        )
                      : DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _selectedCategoryId,
                          items: _categories.map((c) {
                            final m = c as Map;
                            final id = _idOf(m).isNotEmpty ? _idOf(m) : (m['name']?.toString() ?? '');
                            final name = m['name']?.toString() ?? id;
                            return DropdownMenuItem(value: id, child: Text(name));
                          }).toList(),
                          onChanged: (v) => setState(() => _selectedCategoryId = v),
                        ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionCtrl,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Describe the incident',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < 10) {
                        return 'Please provide at least 10 characters.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attach evidence (optional)',
                      style: TextStyle(color: brightText, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickFiles,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Choose file(s) from my computer'),
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ..._attachments.asMap().entries.map((entry) {
                      final i = entry.key;
                      final f = entry.value;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined, color: teal),
                        title: Text(f.name, style: const TextStyle(color: brightText)),
                        subtitle: Text(_fileSize(f.size), style: const TextStyle(color: muted)),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Remove',
                          onPressed: () => _removeFile(i),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _send,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit complaint'),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

class _NotificationsTab extends StatelessWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      fetch: () => Api.list('/student/notifications'),
      builder: (context, items, reload) {
        return Body([
          sectionTitle('Notifications'),
          if (items.isEmpty)
            const EmptyState(Icons.notifications_outlined, 'No notifications.')
          else
            for (final n in items) _NotificationCard(n: n as Map),
        ]);
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final Map n;
  const _NotificationCard({required this.n});

  @override
  Widget build(BuildContext context) {
    final title = n['title']?.toString() ?? 'Notification';
    final message = n['message']?.toString() ?? '';
    final created = fmt(n['createdAt']);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_outlined, color: teal, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: brightText, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: muted, fontSize: 13)),
                if (created.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(created, style: const TextStyle(color: muted, fontSize: 11)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}