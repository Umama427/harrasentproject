import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import '../download_helper.dart';

class CommitteePanel extends StatelessWidget {
  const CommitteePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelScaffold(title: 'Committee Panel', tabs: [
      ('Overview', Icons.dashboard_outlined, _Overview()),
      ('My Cases', Icons.folder_shared_outlined, _Cases()),
    ]);
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return Load<Map<String, dynamic>>(
      fetch: () => Api.obj('/committee/dashboard'),
      builder: (c, d, reload) => Body([
        HeroBanner(
          title: 'Welcome, ${Api.user?['fullName']}',
          subtitle: 'You only see cases that an administrator has assigned to you. Handle each one with care and confidentiality.',
          icon: Icons.balance_outlined,
        ),
        Wrap(spacing: 12, runSpacing: 4, children: [
          StatCard('Assigned to me', d['totalAssigned'], Icons.assignment_ind_outlined),
          StatCard('New assignments', d['assignedNew'], Icons.fiber_new),
          StatCard('Investigating', d['investigating'], Icons.search),
          StatCard('Awaiting student info', d['awaitingInfo'], Icons.mail_outline),
          StatCard('Awaiting decision', d['awaitingDecision'], Icons.gavel),
          StatCard('Resolved', d['resolved'], Icons.check_circle_outline),
        ]),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Refresh'))),
      ]),
    );
  }
}

class _Cases extends StatelessWidget {
  const _Cases();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      fetch: () => Api.list('/committee/cases'),
      builder: (c, items, reload) => Body([
        Row(children: [
          Expanded(child: sectionTitle('Assigned cases')),
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        if (items.isEmpty) const EmptyState(Icons.folder_off_outlined, 'No cases are assigned to you right now.'),
        ...items.map((i) => AppCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                leading: i['immediateSafetyConcern'] == true
                    ? const Icon(Icons.warning_amber, color: Colors.red)
                    : const Icon(Icons.folder_open, color: teal),
                title: Text('${i['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${i['referenceNo']}  •  ${i['categoryId'] is Map ? i['categoryId']['name'] : ''}'),
                trailing: StatusChip('${i['status']}'),
                onTap: () async {
                  await Navigator.of(c).push(MaterialPageRoute(builder: (_) => CaseDetail(id: '${i['_id']}')));
                  reload();
                },
              ),
            )),
      ]),
    );
  }
}

// Matches the backend's allowed committee transitions (the server enforces them anyway).
const _next = {
  'Assigned': ['Under Investigation'],
  'Under Investigation': ['Awaiting Student Information', 'Awaiting Committee Decision'],
  'Awaiting Student Information': ['Under Investigation'],
  'Awaiting Committee Decision': ['Resolved', 'Under Investigation'],
};

class CaseDetail extends StatefulWidget {
  final String id;
  const CaseDetail({super.key, required this.id});

  @override
  State<CaseDetail> createState() => _CaseDetailState();
}

class _CaseDetailState extends State<CaseDetail> {
  final _note = TextEditingController();
  final _findings = TextEditingController();
  final _recommendation = TextEditingController();

  Future<void> _run(Future<void> Function() action, VoidCallback reload, String ok) async {
    try {
      await action();
      if (mounted) snack(context, ok);
      reload();
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  Future<void> _download(String evidenceId, String name) async {
    try {
      final bytes = await Api.downloadBytes('/evidence/$evidenceId/download');
      saveFile(bytes, name);
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  Future<void> _requestEvidence(VoidCallback reload) async {
    try {
      await Api.post('/committee/cases/${widget.id}/request-evidence');
      if (mounted) snack(context, 'Request sent to the student.');
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  Future<void> _conflict() async {
    final reason = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Declare conflict of interest', style: heading(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('You will lose access to this case until an administrator reassigns it.'),
          const SizedBox(height: 12),
          TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Declare')),
        ],
      ),
    );
    if (go != true) return;
    try {
      await Api.post('/committee/cases/${widget.id}/conflict', {'reason': reason.text});
      if (!mounted) return;
      snack(context, 'Conflict recorded.');
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Case details', style: heading(20, color: Colors.white))),
      body: Load<Map<String, dynamic>>(
        fetch: () => Api.obj('/committee/cases/${widget.id}'),
        builder: (c, d, reload) {
          final comp = Map<String, dynamic>.from(d['complaint'] as Map);
          final notes = List<dynamic>.from(d['notes'] as List);
          final witnesses = List<dynamic>.from(d['witnesses'] as List);
          final evidence = List<dynamic>.from(d['evidence'] as List);
          final analyses = List<dynamic>.from(d['analyses'] as List);
          final reviews = List<dynamic>.from(d['reviews'] as List);
          final options = List<String>.from(_next['${comp['status']}'] ?? const <String>[]);
          return Body([
            Text('${comp['title']}', style: heading(26)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${comp['referenceNo']}   ', style: const TextStyle(color: muted)),
              StatusChip('${comp['status']}'),
            ]),
            if (comp['immediateSafetyConcern'] == true)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: AppCard(
                  color: Color(0xFFFDECEA),
                  child: ListTile(
                    leading: Icon(Icons.warning_amber, color: Colors.red),
                    title: Text('Student reported an immediate safety concern'),
                  ),
                ),
              ),
            sectionTitle('Description'),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${comp['description']}', style: const TextStyle(height: 1.5)),
                if (comp['incidentLocation'] != null)
                  Padding(padding: const EdgeInsets.only(top: 10), child: Text('Location: ${comp['incidentLocation']}', style: const TextStyle(color: muted))),
                if (comp['accused'] is Map && comp['accused']['name'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Accused: ${comp['accused']['name']} (${comp['accused']['relationship'] ?? ''})', style: const TextStyle(color: muted)),
                  ),
              ]),
            ),
            sectionTitle('Witnesses (restricted)'),
            if (witnesses.isEmpty)
              const EmptyState(Icons.person_outline, 'No witnesses listed.')
            else
              AppCard(
                child: Column(
                  children: witnesses
                      .map((w) => ListTile(
                            leading: const Icon(Icons.person_outline, color: teal),
                            title: Text('${w['name']}'),
                            subtitle: Text('${w['contact'] ?? ''}'),
                          ))
                      .toList(),
                ),
              ),
            sectionTitle('Evidence'),
            if (evidence.isEmpty)
              const EmptyState(Icons.attach_file, 'No files attached.')
            else
              AppCard(
                child: Column(
                  children: evidence.map((e) {
                    final a = analyses.where((x) => '${x['evidenceId']}' == '${e['_id']}').toList();
                    return ListTile(
                      leading: const Icon(Icons.attach_file, color: teal),
                      title: Text('${e['originalName']}'),
                      subtitle: Text(a.isEmpty
                          ? 'No AI analysis for this file type'
                          : 'AI check: ${a.first['result']} (indicative only, not proof)'),
                      trailing: IconButton(
                        icon: const Icon(Icons.download, color: teal),
                        onPressed: () => _download('${e['_id']}', '${e['originalName']}'),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.mark_email_unread_outlined),
                  label: const Text('Request evidence from student'),
                  onPressed: () => _requestEvidence(reload),
                ),
              ),
            ),
            sectionTitle('Update status'),
            if (options.isEmpty) const Text('No status changes available right now.', style: TextStyle(color: muted)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options
                  .map((o) => FilledButton(
                        onPressed: () => _run(() async {
                          await Api.post('/committee/cases/${widget.id}/status', {'status': o});
                        }, reload, 'Status updated.'),
                        child: Text(o),
                      ))
                  .toList(),
            ),
            sectionTitle('Internal notes (never shown to the student)'),
            ...notes.map((n) => AppCard(child: ListTile(title: Text('${n['note']}'), subtitle: Text(fmt(n['createdAt']))))),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(labelText: 'Add a private note')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _run(() async {
                    await Api.post('/committee/cases/${widget.id}/notes', {'note': _note.text});
                    _note.clear();
                  }, reload, 'Note saved.'),
                  child: const Text('Save note'),
                ),
              ]),
            ),
            sectionTitle('Findings and recommendation'),
            ...reviews.map((r) => AppCard(child: ListTile(title: Text('${r['findings'] ?? ''}'), subtitle: Text('${r['recommendation'] ?? ''}')))),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: _findings, maxLines: 3, decoration: const InputDecoration(labelText: 'Findings')),
                const SizedBox(height: 12),
                TextField(controller: _recommendation, maxLines: 2, decoration: const InputDecoration(labelText: 'Recommendation')),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _run(() async {
                    await Api.post('/committee/cases/${widget.id}/review', {'findings': _findings.text, 'recommendation': _recommendation.text});
                    _findings.clear();
                    _recommendation.clear();
                  }, reload, 'Review saved.'),
                  child: const Text('Save review'),
                ),
              ]),
            ),
            sectionTitle('Timeline'),
            Timeline(List<dynamic>.from(d['timeline'] as List)),
            const Divider(height: 40),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.report_gmailerrorred),
                label: const Text('Declare conflict of interest'),
                onPressed: _conflict,
              ),
            ),
          ]);
        },
      ),
    );
  }
}