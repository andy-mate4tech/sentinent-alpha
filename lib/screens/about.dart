import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'shell.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key, required this.state});
  final AppState state;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final TextEditingController _url;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.state.backendUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          TerminalHeader(state: s, title: 'About', subtitle: 'RESEARCH TERMINAL'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AlphaCard(
              child: const Text(
                'No sign-in and no app backend. Holdings live on this device. Quotes come from Yahoo Finance public chart/search endpoints. The Desk tab walks the same seats as Tauric Research TradingAgents (analysts, bull/bear, trader, risk, PM) using that tape.\n\n'
                'The real TradingAgents repo is a Python LangGraph firm. It needs an LLM key and cannot run inside this APK. Paste a FastAPI URL below to swap the local desk for TradingAgentsGraph.propagate(ticker, date). See ARCHITECTURE.md in the project.',
                style: TextStyle(color: SA.muted, height: 1.45, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AlphaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Optional Tauric backend', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _url,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'https://host:8000',
                      hintText: 'http://192.168.1.10:8000',
                    ),
                  ),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Save backend URL',
                    icon: Icons.link,
                    onPressed: () async {
                      await s.setBackendUrl(_url.text);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            s.backendUrl.isEmpty
                                ? 'Using on-device desk'
                                : 'Desk will call ${s.backendUrl}',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: AlphaCard(
              child: Text(
                'github.com/TauricResearch/TradingAgents is Apache-2.0 and research-only. It is not financial advice. This APK is a tracker plus a local stand-in for that firm. Performance of any rating can vary with models, data, and dates.',
                style: TextStyle(color: SA.muted, height: 1.45, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
