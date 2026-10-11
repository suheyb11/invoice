// Admin panel: approve users, give privileges, and see every action in the company.
import 'package:flutter/material.dart';

import '../db.dart';
import '../models.dart';
import '../widgets.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.manage_accounts_rounded), text: 'Users'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Activity'),
            ],
          ),
        ),
        body: const TabBarView(children: [UsersTab(), ActivityTab()]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Users
class UsersTab extends StatefulWidget {
  const UsersTab({super.key});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  List<Member>? list;
  String error = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final l = await AppDb.members();
      if (mounted) setState(() => list = l);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
  }

  Future<void> open(Member m) async {
    await Navigator.push(context, slideRoute(MemberScreen(member: m)));
    load();
  }

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) return EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load users', subtitle: error);
    if (list == null) return const Center(child: CircularProgressIndicator());
    final pending = list!.where((m) => !m.active).length;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (pending > 0)
            FadeSlideIn(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Palette.orange.withAlpha(28), borderRadius: BorderRadius.circular(16)),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Palette.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child:
                          Text('$pending user(s) waiting for approval or blocked.', style: const TextStyle(color: Palette.orange, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          for (var i = 0; i < list!.length; i++)
            FadeSlideIn(
              index: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  onTap: () => open(list![i]),
                  child: Row(
                    children: [
                      InitialsAvatar(list![i].email),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(list![i].email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              list![i].isAdmin ? 'All privileges' : '${list![i].permCount} of ${permLabels.length} privileges',
                              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      AccessChip(list![i]),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AccessChip extends StatelessWidget {
  final Member m;
  const AccessChip(this.m, {super.key});

  @override
  Widget build(BuildContext context) {
    final (text, color) = !m.active
        ? (m.permCount == 0 ? ('WAITING', Palette.orange) : ('BLOCKED', Palette.red))
        : (m.isAdmin ? ('ADMIN', Palette.blue) : ('STAFF', Palette.green));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );
  }
}

// ---------------------------------------------------------------- One user: access + their actions
class MemberScreen extends StatefulWidget {
  final Member member;
  const MemberScreen({super.key, required this.member});

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen> {
  late Member m;
  bool saving = false;
  List<LogEntry>? actions;

  bool get isMe => widget.member.uid == AppDb.uid;

  @override
  void initState() {
    super.initState();
    final w = widget.member;
    m = Member(uid: w.uid, email: w.email, role: w.role, active: w.active, perms: Map.of(w.perms), theme: w.theme, createdAt: w.createdAt);
    AppDb.allActivity(byUid: w.uid).then((l) {
      if (mounted) setState(() => actions = l);
    });
  }

  void setAll(bool on) {
    setState(() {
      for (final k in permLabels.keys) {
        m.perms[k] = on;
      }
    });
  }

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await AppDb.saveMember(m, widget.member);
      if (!mounted) return;
      toast(context, 'Access saved for ${m.email}.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        toast(context, errorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = isMe;
    final allOn = permLabels.keys.every((k) => m.perms[k] == true);
    return Scaffold(
      appBar: AppBar(title: const Text('User access')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          FadeSlideIn(
            child: AppCard(
              child: Row(
                children: [
                  InitialsAvatar(m.email),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.email, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('Joined ${niceDateTime(m.createdAt)}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  AccessChip(m),
                ],
              ),
            ),
          ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('This is your own account. Another admin must change your access.', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          const SectionTitle('Access'),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  SwitchListTile(
                    value: m.active,
                    onChanged: locked ? null : (v) => setState(() => m.active = v),
                    title: const Text('Approved'),
                    subtitle: Text(m.active ? 'Can sign in and use the app' : 'Cannot see or change any data'),
                    secondary: Icon(m.active ? Icons.verified_user_rounded : Icons.block_rounded, color: m.active ? Palette.green : Palette.red),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'staff', label: Text('Staff'), icon: Icon(Icons.badge_outlined)),
                        ButtonSegment(value: 'admin', label: Text('Admin'), icon: Icon(Icons.admin_panel_settings_rounded)),
                      ],
                      selected: {m.role},
                      onSelectionChanged: locked ? null : (s) => setState(() => m.role = s.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle(
            'Privileges',
            trailing: m.isAdmin || locked
                ? null
                : TextButton.icon(
                    onPressed: () => setAll(!allOn),
                    icon: Icon(allOn ? Icons.remove_done_rounded : Icons.done_all_rounded, size: 18),
                    label: Text(allOn ? 'Remove all' : 'Give all'),
                  ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: m.isAdmin
                ? AppCard(child: Text('Admins have every privilege and can open this admin panel.', style: TextStyle(color: scheme.onSurfaceVariant)))
                : Column(
                    children: [
                      for (final g in permGroups.entries)
                        FadeSlideIn(
                          index: 2,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                                    child: Text(g.key, style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
                                  ),
                                  for (final k in g.value)
                                    CheckboxListTile(
                                      dense: true,
                                      value: m.perms[k] == true,
                                      onChanged: locked ? null : (v) => setState(() => m.perms[k] = v == true),
                                      title: Text(permLabels[k]!),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          if (!locked) ColorButton(text: 'Save access', icon: Icons.save_rounded, busy: saving, onPressed: save),
          SectionTitle('Actions by this user', trailing: actions == null ? null : Text('${actions!.length}')),
          if (actions == null)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))
          else if (actions!.isEmpty)
            AppCard(child: Text('No actions yet.', style: TextStyle(color: scheme.onSurfaceVariant)))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [for (final a in actions!.take(50)) LogTile(a, showUser: false)]),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Activity (every action)
class ActivityTab extends StatefulWidget {
  const ActivityTab({super.key});

  @override
  State<ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<ActivityTab> {
  List<LogEntry>? list;
  String error = '';
  String search = '';
  String type = 'all';

  static const types = {
    'all': 'All',
    'invoice': 'Invoices',
    'quote': 'Quotes',
    'customer': 'Customers',
    'product': 'Products',
    'member': 'Users',
    'settings': 'Settings',
  };

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final l = await AppDb.allActivity();
      if (mounted) setState(() => list = l);
    } catch (e) {
      if (mounted) setState(() => error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (error.isNotEmpty) return EmptyState(icon: Icons.error_outline_rounded, title: 'Could not load activity', subtitle: error);
    if (list == null) return const Center(child: CircularProgressIndicator());
    final s = search.toLowerCase().trim();
    final shown = list!.where((a) {
      if (type != 'all' && a.type != type && !(type == 'settings' && a.type == 'data')) return false;
      if (s.isEmpty) return true;
      return a.action.toLowerCase().contains(s) || a.label.toLowerCase().contains(s) || a.byEmail.toLowerCase().contains(s);
    }).toList();
    return Column(
      children: [
        const SizedBox(height: 8),
        SearchBox(hint: 'Search user, action or number', onChanged: (v) => setState(() => search = v)),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final t in types.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(label: Text(t.value), selected: type == t.key, onSelected: (_) => setState(() => type = t.key)),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: load,
            child: shown.isEmpty
                ? ListView(children: const [SizedBox(height: 80), EmptyState(icon: Icons.history_rounded, title: 'No actions found')])
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: shown.length,
                    itemBuilder: (context, i) => FadeSlideIn(
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppCard(padding: const EdgeInsets.symmetric(vertical: 2), child: LogTile(shown[i])),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class LogTile extends StatelessWidget {
  final LogEntry a;
  final bool showUser;
  const LogTile(this.a, {super.key, this.showUser = true});

  static (IconData, Color) look(String type) {
    switch (type) {
      case 'invoice':
        return (Icons.receipt_long_rounded, Palette.blue);
      case 'quote':
        return (Icons.request_quote_rounded, Palette.orange);
      case 'customer':
        return (Icons.person_rounded, Palette.cyan);
      case 'product':
        return (Icons.inventory_2_rounded, Palette.green);
      case 'member':
        return (Icons.admin_panel_settings_rounded, Palette.blue);
      case 'data':
        return (Icons.delete_forever_rounded, Palette.red);
      default:
        return (Icons.tune_rounded, Colors.blueGrey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = look(a.type);
    final who = a.byEmail.isEmpty ? 'System' : a.byEmail;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(a.label.isEmpty ? a.action : '${a.label} · ${a.action}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(showUser ? '$who\n${niceDateTime(a.createdAt)}' : niceDateTime(a.createdAt), style: const TextStyle(fontSize: 12.5)),
      isThreeLine: showUser,
    );
  }
}
