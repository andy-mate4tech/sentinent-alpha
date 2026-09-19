import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentient_alpha/screens/book_tab.dart';
import 'package:sentient_alpha/screens/copilot_tab.dart';
import 'package:sentient_alpha/screens/desk_tab.dart';
import 'package:sentient_alpha/screens/more_tab.dart';
import 'package:sentient_alpha/screens/onboarding.dart';
import 'package:sentient_alpha/screens/track_tab.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';

class SentientAlphaApp extends ConsumerWidget {
  const SentientAlphaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Sentient Alpha',
      debugShowCheckedModeBanner: false,
      theme: SA.dark(),
      home: const _Root(),
    );
  }
}

class _Root extends ConsumerStatefulWidget {
  const _Root();

  @override
  ConsumerState<_Root> createState() => _RootState();
}

class _RootState extends ConsumerState<_Root> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider);
    if (!book.disclaimerAccepted) {
      return const OnboardingScreen();
    }
    final pages = [
      const TrackTab(),
      const BookTab(),
      const DeskTab(),
      const CopilotTab(),
      const MoreTab(),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.add_chart), label: 'Track'),
          NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Book'),
          NavigationDestination(icon: Icon(Icons.psychology_alt_outlined), label: 'Desk'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Copilot'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}
