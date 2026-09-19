import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'about.dart';
import 'copilot.dart';
import 'desk.dart';
import 'track.dart';

class ShellScreen extends StatelessWidget {
  const ShellScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TrackScreen(state: state),
      DeskScreen(state: state),
      CopilotScreen(state: state),
      AboutScreen(state: state),
    ];
    return Scaffold(
      body: IndexedStack(index: state.tab, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xCC0B0F19),
        indicatorColor: SA.mint.withValues(alpha: 0.18),
        selectedIndex: state.tab,
        onDestinationSelected: state.setTab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart, color: SA.mint),
            label: 'Track',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment, color: SA.mint),
            label: 'Desk',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon: Icon(Icons.auto_awesome, color: SA.mint),
            label: 'Copilot',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info, color: SA.mint),
            label: 'About',
          ),
        ],
      ),
    );
  }
}

class TerminalHeader extends StatelessWidget {
  const TerminalHeader({
    super.key,
    required this.state,
    required this.title,
    this.subtitle,
  });

  final AppState state;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final live = state.lastRefreshNote ?? (state.holdings.isEmpty ? 'READY' : 'WAITING');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: SA.surface2,
                  border: Border.all(color: SA.cyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.show_chart, size: 16, color: SA.cyan),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          color: SA.mint,
                          letterSpacing: 0.6,
                        ),
                      ),
                  ],
                ),
              ),
              Pill(
                state.backendUrl.isEmpty ? 'LOCAL DESK' : 'TAURIC LINKED',
                color: state.backendUrl.isEmpty ? SA.cyan : SA.mint,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${state.holdings.length} LOTS',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  color: SA.muted,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.circle,
                size: 8,
                color: state.error == null ? SA.mint : SA.coral,
              ),
              const SizedBox(width: 4),
              Text(
                live,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  color: state.error == null ? SA.mint : SA.coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
