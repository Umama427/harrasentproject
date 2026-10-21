import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets.dart';
import '../download_helper.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return const PanelScaffold(title: 'Admin Panel', tabs: [
      ('Overview', Icons.dashboard_outlined, _Overview()),
      ('Complaints', Icons.list_alt, _Complaints()),
      ('Committee', Icons.groups_outlined, _Committee()),
      ('Users', Icons.people_outline, _Users()),
      ('Manage', Icons.settings_outlined, _Manage()),
      ('Audit Log', Icons.history, _Audit()),
    ]);
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    return Load<Map<String, dynamic>>(
      fetch: () => Api.obj('/admin/dashboard'),
      builder: (c, d, reload) {
        final recent = List<dynamic>.from(d['recent'] as List);
        return Body([
          const HeroBanner(
            title: 'System overview',
            subtitle: 'Monitor complaints, assign cases to the committee and manage the people and content of the system.',
            icon: Icons.admin_panel_settings_outlined,
          ),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Refresh'))),
          Wrap(spacing: 12, runSpacing: 4, children: [
            StatCard('Total users', d['users'], Icons.people),
            StatCard('Students', d['students'], Icons.school_outlined),
            StatCard('Committee members', d['committee'], Icons.groups_outlined),
            StatCard('Total complaints', d['total'], Icons.folder_open),
            StatCard('Pending', d['pending'], Icons.hourglass_empty),
            StatCard('Under investigation', d['investigating'], Icons.search),
            StatCard('Resolved', d['resolved'], Icons.check_circle_outline),
          ]),
          sectionTitle('Recent administrative activity'),
          if (recent.isEmpty)
            const EmptyState(Icons.bolt, 'No activity yet.')
          else
            AppCard(
              child: Column(
                children: recent
                    .map((a) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.bolt, color: gold),
                          title: Text('${a['action']}'),
                          subtitle: Text(fmt(a['createdAt'])),
                        ))
                    .toList(),
              ),
            ),
        ]);
      },
    );
  }
}

class _Complaints extends StatelessWidget {
  const _Complaints();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      fetch: () => Api.list('/admin/complaints'),
      builder: (c, items, reload) => Body([
        Row(children: [
          Expanded(child: sectionTitle('All complaints')),
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        if (items.isEmpty) const EmptyState(Icons.inbox_outlined, 'No complaints have been submitted yet.'),
        ...items.map((i) => AppCard(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                leading: i['immediateSafetyConcern'] == true
                    ? const Icon(Icons.warning_amber, color: Colors.red)
                    : const Icon(Icons.folder_open, color: teal),
                title: Text('${i['referenceNo']}  •  ${i['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${i['studentId'] is Map ? i['studentId']['fullName'] : ''}  •  Assigned to: ${i['assignedTo'] is Map ? i['assignedTo']['fullName'] : 'nobody yet'}'),
                trailing: StatusChip('${i['status']}'),
                onTap: () async {
                  await Navigator.of(c).push(MaterialPageRoute(builder: (_) => AdminComplaintDetail(id: '${i['_id']}')));
                  reload();
                },
              ),
            )),
      ]),
    );
  }
}

class AdminComplaintDetail extends StatefulWidget {
  final String id;
  const AdminComplaintDetail({super.key, required this.id});

  @override
  State<AdminComplaintDetail> createState() => _AdminComplaintDetailState();
}

class _AdminComplaintDetailState extends State<AdminComplaintDetail> {
  String? _assignee;

  Future<void> _assign(VoidCallback reload) async {
    if (_assignee == null) {
      snack(context, 'Choose a committee member first.');
      return;
    }
    try {
      await Api.post('/admin/complaints/${widget.id}/assign', {'assigneeId': _assignee});
      if (mounted) snack(context, 'Complaint assigned.');
      reload();
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  Future<void> _status(String status, VoidCallback reload) async {
    try {
      await Api.post('/admin/complaints/${widget.id}/status', {'status': status});
      if (mounted) snack(context, 'Status updated.');
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
      await Api.post('/admin/complaints/${widget.id}/request-evidence');
      if (mounted) snack(context, 'Request sent to the student.');
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Complaint review', style: heading(20, color: Colors.white))),
      body: Load<List<dynamic>>(
        fetch: () async => [await Api.obj('/admin/complaints/${widget.id}'), await Api.list('/admin/committee-members')],
        builder: (c, both, reload) {
          final d = Map<String, dynamic>.from(both[0] as Map);
          final members = List<dynamic>.from(both[1] as List).where((m) => m['isActive'] != false && m['userId'] is Map).toList();
          final comp = Map<String, dynamic>.from(d['complaint'] as Map);
          final student = comp['studentId'] is Map ? comp['studentId'] as Map : {};
          final evidence = List<dynamic>.from(d['evidence'] as List);
          final assignments = List<dynamic>.from(d['assignments'] as List);
          final status = '${comp['status']}';
          final adminNext = const {
            'Submitted': ['Under Initial Review', 'Rejected'],
            'Under Initial Review': ['Awaiting Assignment', 'Rejected'],
            'Resolved': ['Closed', 'Reopened'],
            'Closed': ['Reopened'],
            'Reopened': ['Awaiting Assignment'],
          }[status] ?? const <String>[];
          return Body([
            Text('${comp['title']}', style: heading(26)),
            const SizedBox(height: 8),
            Row(children: [
              Text('${comp['referenceNo']}   ', style: const TextStyle(color: muted)),
              StatusChip(status),
            ]),
            const SizedBox(height: 6),
            Text('Student: ${student['fullName'] ?? ''}  (${student['registrationNumber'] ?? ''})', style: const TextStyle(color: muted)),
            sectionTitle('Description'),
            AppCard(padding: const EdgeInsets.all(18), child: Text('${comp['description']}', style: const TextStyle(height: 1.5))),
            sectionTitle('Evidence'),
            if (evidence.isEmpty)
              const EmptyState(Icons.attach_file, 'No files attached.')
            else
              AppCard(
                child: Column(
                  children: evidence
                      .map((e) => ListTile(
                            leading: const Icon(Icons.attach_file, color: teal),
                            title: Text('${e['originalName']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.download, color: teal),
                              onPressed: () => _download('${e['_id']}', '${e['originalName']}'),
                            ),
                          ))
                      .toList(),
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
            sectionTitle('Assign to committee'),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                DropdownButtonFormField<String>(
                  initialValue: _assignee,
                  decoration: const InputDecoration(labelText: 'Committee member or HOD'),
                  items: members
                      .map((m) => DropdownMenuItem(
                          value: '${m['userId']['_id']}', child: Text('${m['userId']['fullName']}  (${m['designation'] ?? 'Member'})')))
                      .toList(),
                  onChanged: (v) => setState(() => _assignee = v),
                ),
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('No committee members yet. Add one in the Committee tab.', style: TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 14),
                FilledButton(onPressed: () => _assign(reload), child: const Text('Assign complaint')),
              ]),
            ),
            if (assignments.isNotEmpty) sectionTitle('Assignment history'),
            if (assignments.isNotEmpty)
              AppCard(
                child: Column(
                  children: assignments
                      .map((a) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.assignment_ind_outlined, color: teal),
                            title: Text('${a['assigneeId'] is Map ? a['assigneeId']['fullName'] : ''}'),
                            subtitle: Text('${fmt(a['createdAt'])}${a['conflictDeclared'] == true ? '  •  conflict declared: ${a['conflictReason'] ?? ''}' : ''}${a['active'] == true ? '  •  active' : ''}'),
                          ))
                      .toList(),
                ),
              ),
            if (adminNext.isNotEmpty) sectionTitle('Change status'),
            Wrap(spacing: 8, runSpacing: 8, children: adminNext.map((s) => OutlinedButton(onPressed: () => _status(s, reload), child: Text(s))).toList()),
            sectionTitle('Timeline'),
            Timeline(List<dynamic>.from(d['timeline'] as List)),
          ]);
        },
      ),
    );
  }
}

class _Committee extends StatefulWidget {
  const _Committee();

  @override
  State<_Committee> createState() => _CommitteeState();
}

class _CommitteeState extends State<_Committee> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  String _designation = 'Member';
  String? _dept;
  Key _k = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      key: _k,
      fetch: () async => [await Api.list('/admin/committee-members'), await Api.list('/public/departments')],
      builder: (c, d, reload) {
        final members = List<dynamic>.from(d[0] as List);
        final depts = List<dynamic>.from(d[1] as List);
        return Body([
          sectionTitle('Committee members and HODs'),
          if (members.isEmpty) const EmptyState(Icons.groups_outlined, 'No committee members yet.'),
          ...members.map((m) => AppCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  leading: const Icon(Icons.badge_outlined, color: teal),
                  title: Text('${m['userId'] is Map ? m['userId']['fullName'] : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${m['userId'] is Map ? m['userId']['email'] : ''}  •  ${m['designation']}  •  ${m['departmentId'] is Map ? m['departmentId']['name'] : ''}'),
                ),
              )),
          sectionTitle('Add a committee member'),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password (8+ characters)')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _dept,
                decoration: const InputDecoration(labelText: 'Department'),
                items: depts.map((x) => DropdownMenuItem(value: '${x['_id']}', child: Text('${x['name']}'))).toList(),
                onChanged: (v) => setState(() => _dept = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _designation,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'Member', child: Text('Committee Member')),
                  DropdownMenuItem(value: 'HOD', child: Text('Committee HOD')),
                ],
                onChanged: (v) => setState(() => _designation = v ?? 'Member'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await Api.post('/admin/committee-members', {
                      'fullName': _name.text.trim(),
                      'email': _email.text.trim(),
                      'password': _pass.text,
                      'departmentId': _dept,
                      'designation': _designation,
                    });
                    _name.clear();
                    _email.clear();
                    _pass.clear();
                    if (c.mounted) snack(c, 'Committee member created.');
                    setState(() => _k = UniqueKey());
                  } catch (e) {
                    if (c.mounted) snack(c, e.toString());
                  }
                },
                child: const Text('Create account'),
              ),
            ]),
          ),
        ]);
      },
    );
  }
}

class _Users extends StatelessWidget {
  const _Users();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      fetch: () => Api.list('/admin/users'),
      builder: (c, users, reload) => Body([
        Row(children: [
          Expanded(child: sectionTitle('Users')),
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        ...users.map((u) {
          final active = u['status'] != 'suspended';
          return AppCard(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: CircleAvatar(
                backgroundColor: navy,
                child: Text('${u['fullName']}'.isEmpty ? '?' : '${u['fullName']}'[0].toUpperCase(), style: const TextStyle(color: gold, fontWeight: FontWeight.bold)),
              ),
              title: Text('${u['fullName']}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${u['email']}  •  ${u['roleName']}'),
              trailing: u['roleName'] == 'Admin'
                  ? null
                  : TextButton(
                      onPressed: () async {
                        try {
                          await Api.post('/admin/users/${u['_id']}/status', {'status': active ? 'suspended' : 'active'});
                          reload();
                        } catch (e) {
                          if (c.mounted) snack(c, e.toString());
                        }
                      },
                      child: Text(active ? 'Suspend' : 'Activate'),
                    ),
            ),
          );
        }),
      ]),
    );
  }
}

class _Manage extends StatefulWidget {
  const _Manage();

  @override
  State<_Manage> createState() => _ManageState();
}

class _ManageState extends State<_Manage> {
  final _dName = TextEditingController();
  final _dCode = TextEditingController();
  final _sName = TextEditingController();
  final _sNum = TextEditingController();
  final _cName = TextEditingController();
  final _pTitle = TextEditingController();
  final _pContent = TextEditingController();
  final _svName = TextEditingController();
  final _svContact = TextEditingController();

  Future<void> _add(String path, Map<String, dynamic> body, List<TextEditingController> clear, String ok) async {
    try {
      await Api.post('/admin/$path', body);
      for (final c in clear) {
        c.clear();
      }
      if (mounted) snack(context, ok);
    } catch (e) {
      if (mounted) snack(context, e.toString());
    }
  }

  Widget _box(String title, List<Widget> fields, VoidCallback onAdd) => AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: heading(18)),
          const SizedBox(height: 12),
          ...fields.expand((f) => [f, const SizedBox(height: 10)]),
          const SizedBox(height: 4),
          FilledButton(onPressed: onAdd, child: const Text('Add')),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Body([
      sectionTitle('Reference data and content'),
      _box('New department', [
        TextField(controller: _dName, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: _dCode, decoration: const InputDecoration(labelText: 'Code (e.g. CS)')),
      ], () => _add('departments', {'name': _dName.text.trim(), 'code': _dCode.text.trim()}, [_dName, _dCode], 'Department added.')),
      _box('New semester', [
        TextField(controller: _sName, decoration: const InputDecoration(labelText: 'Name (e.g. Semester 9)')),
        TextField(controller: _sNum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number')),
      ], () => _add('semesters', {'name': _sName.text.trim(), 'number': int.tryParse(_sNum.text.trim())}, [_sName, _sNum], 'Semester added.')),
      _box('New complaint category', [
        TextField(controller: _cName, decoration: const InputDecoration(labelText: 'Category name')),
      ], () => _add('categories', {'name': _cName.text.trim()}, [_cName], 'Category added.')),
      _box('New policy', [
        TextField(controller: _pTitle, decoration: const InputDecoration(labelText: 'Title')),
        TextField(controller: _pContent, maxLines: 4, decoration: const InputDecoration(labelText: 'Content')),
      ], () => _add('policies', {'title': _pTitle.text.trim(), 'content': _pContent.text.trim()}, [_pTitle, _pContent], 'Policy added.')),
      _box('New support service', [
        TextField(controller: _svName, decoration: const InputDecoration(labelText: 'Name')),
        TextField(controller: _svContact, decoration: const InputDecoration(labelText: 'Contact details')),
      ], () => _add('support-services', {'name': _svName.text.trim(), 'contact': _svContact.text.trim()}, [_svName, _svContact], 'Support service added.')),
    ]);
  }
}

class _Audit extends StatelessWidget {
  const _Audit();

  @override
  Widget build(BuildContext context) {
    return Load<List<dynamic>>(
      fetch: () => Api.list('/admin/audit-logs'),
      builder: (c, logs, reload) => Body([
        Row(children: [
          Expanded(child: sectionTitle('Audit log')),
          IconButton(onPressed: reload, icon: const Icon(Icons.refresh)),
        ]),
        if (logs.isEmpty)
          const EmptyState(Icons.history, 'Nothing recorded yet.')
        else
          AppCard(
            child: Column(
              children: logs
                  .map((l) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, color: teal),
                        title: Text('${l['action']}'),
                        subtitle: Text('${l['actorId'] is Map ? l['actorId']['fullName'] : ''}  •  ${fmt(l['createdAt'])}'),
                      ))
                  .toList(),
            ),
          ),
      ]),
    );
  }
}