import 'package:flutter/material.dart';
import 'api.dart';
import 'theme.dart';
import 'auth/login_screen.dart';

String fmt(dynamic iso) {
  if (iso == null) return '';
  try {
    return DateTime.parse(iso.toString()).toLocal().toString().substring(0, 16);
  } catch (_) {
    return iso.toString();
  }
}

void snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _today() {
  const days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
}

// ---------------------------------------------------------------- building blocks

class AppCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;

  const AppCard({
    super.key,
    required this.child,
    this.color,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: color ?? surfaceColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: line),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

class HeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.shield_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B1B2A),
            Color(0xFF10364A),
            Color(0xFF07516A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: teal.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: teal.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -70,
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teal.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            right: 100,
            bottom: -100,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.035),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: teal,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: teal.withValues(alpha: 0.7),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(title, style: heading(28)),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 15,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 20),
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: teal.withValues(alpha: 0.08),
                          border: Border.all(color: teal.withValues(alpha: 0.55)),
                        ),
                        child: Icon(icon, color: teal, size: 28),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final dynamic value;
  final IconData icon;

  const StatCard(this.label, this.value, this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    const palette = [
      teal,
      gold,
      Color(0xFF8B9EFF),
      Color(0xFFFF7F87),
      Color(0xFF61D6A8),
    ];
    final accent = palette[label.length % palette.length];

    return SizedBox(
      width: 215,
      child: AppCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withValues(alpha: 0.16)),
              ),
              child: Icon(icon, color: accent, size: 21),
            ),
            const SizedBox(height: 16),
            Text('$value', style: heading(32)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color color = muted;

    if (status == 'Resolved' || status == 'Closed') {
      color = const Color(0xFF61D6A8);
    } else if (status == 'Rejected') {
      color = const Color(0xFFFF7F87);
    } else if (status.startsWith('Under') || status.startsWith('Awaiting')) {
      color = gold;
    } else if (status == 'Assigned') {
      color = teal;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 7),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class Timeline extends StatelessWidget {
  final List<dynamic> items;

  const Timeline(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text(
        'No activity yet.',
        style: TextStyle(color: muted),
      );
    }

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 26,
                    child: Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: i == items.length - 1 ? teal : navySoft,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: i == items.length - 1 ? teal : muted,
                              width: 2,
                            ),
                          ),
                        ),
                        if (i != items.length - 1)
                          Expanded(
                            child: Container(width: 2, color: line),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18, left: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${items[i]['fromStatus'] ?? 'Start'}  →  ${items[i]['toStatus']}',
                            style: const TextStyle(
                              color: brightText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            fmt(items[i]['createdAt']),
                            style: const TextStyle(
                              color: muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget sectionTitle(String title) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: teal,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(color: teal.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(title, style: heading(20)),
        ],
      ),
    );

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyState(this.icon, this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: teal.withValues(alpha: 0.09),
                shape: BoxShape.circle,
                border: Border.all(color: teal.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: teal, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

class Body extends StatelessWidget {
  final List<Widget> children;

  const Body(this.children, {super.key});

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.of(context).size.width < 700;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: ListView(
          padding: EdgeInsets.all(narrow ? 16 : 28),
          children: children,
        ),
      ),
    );
  }
}

class Load<T> extends StatefulWidget {
  final Future<T> Function() fetch;
  final Widget Function(BuildContext, T, VoidCallback) builder;

  const Load({
    super.key,
    required this.fetch,
    required this.builder,
  });

  @override
  State<Load<T>> createState() => _LoadState<T>();
}

class _LoadState<T> extends State<Load<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.fetch();
  }

  void _reload() {
    setState(() {
      _future = widget.fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: teal),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AppCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 40,
                      color: Color(0xFFFF7F87),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: _reload,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

// ---------------------------------------------------------------- app shell

class PanelScaffold extends StatefulWidget {
  final String title;
  final List<(String, IconData, Widget)> tabs;

  const PanelScaffold({
    super.key,
    required this.title,
    required this.tabs,
  });

  @override
  State<PanelScaffold> createState() => _PanelScaffoldState();
}

class _PanelScaffoldState extends State<PanelScaffold> {
  int _index = 0;

  void _logout() {
    Api.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget _sidebar({required bool inDrawer}) {
    final name = '${Api.user?['fullName'] ?? ''}'.trim();
    final role = '${Api.user?['role'] ?? ''}';
    final initials = name.isEmpty
        ? '?'
        : name
            .split(RegExp(r'\s+'))
            .take(2)
            .map((word) => word[0].toUpperCase())
            .join();

    return Container(
      width: inDrawer ? double.infinity : 262,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [navyDeep, navy, Color(0xFF0B1A29)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(right: BorderSide(color: line)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 8),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: teal.withValues(alpha: 0.8)),
                      color: teal.withValues(alpha: 0.08),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: teal,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NidaaCare', style: heading(19)),
                        Text(
                          widget.title.toUpperCase(),
                          style: const TextStyle(
                            color: teal,
                            fontSize: 10.5,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (int index = 0; index < widget.tabs.length; index++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setState(() => _index = index);
                          if (inDrawer) Navigator.of(context).pop();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: index == _index
                                ? teal.withValues(alpha: 0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: index == _index
                                  ? teal.withValues(alpha: 0.22)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.tabs[index].$2,
                                size: 20,
                                color: index == _index ? teal : muted,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  widget.tabs[index].$1,
                                  style: TextStyle(
                                    color: index == _index
                                        ? brightText
                                        : muted,
                                    fontWeight: index == _index
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: teal.withValues(alpha: 0.16),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: brightText,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          role,
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sign out',
                    onPressed: _logout,
                    icon: const Icon(
                      Icons.logout,
                      color: muted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tabs.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No dashboard sections available.')),
      );
    }

    final wide = MediaQuery.of(context).size.width >= 900;
    final content = KeyedSubtree(
      key: ValueKey(_index),
      child: widget.tabs[_index].$3,
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _sidebar(inDrawer: false),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: const BoxDecoration(
                      color: navy,
                      border: Border(bottom: BorderSide(color: line)),
                    ),
                    child: Row(
                      children: [
                        Text(widget.tabs[_index].$1, style: heading(22)),
                        const Spacer(),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: muted,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _today(),
                          style: const TextStyle(color: muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tabs[_index].$1, style: heading(20)),
      ),
      drawer: Drawer(
        width: 280,
        backgroundColor: navy,
        child: _sidebar(inDrawer: true),
      ),
      body: content,
    );
  }
}