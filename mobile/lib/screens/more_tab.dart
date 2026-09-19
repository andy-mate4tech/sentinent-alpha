import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentient_alpha/state/book_controller.dart';
import 'package:sentient_alpha/theme.dart';

class MoreTab extends ConsumerStatefulWidget {
  const MoreTab({super.key});

  @override
  ConsumerState<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends ConsumerState<MoreTab> {
  final urlCtrl = TextEditingController();
  final pairCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final api = ref.read(apiProvider);
      await api.load();
      urlCtrl.text = api.baseUrl ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(bookProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('MORE', style: SA.mono(size: 12, color: SA.cyan)),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Backend base URL',
              hintText: 'http://192.168.x.x:8010',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pairCtrl,
            decoration: const InputDecoration(labelText: 'Pairing code (if required)'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              await ref.read(bookProvider.notifier).setBackend(
                    urlCtrl.text,
                    pairing: pairCtrl.text.trim().isEmpty ? null : pairCtrl.text.trim(),
                  );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(ref.read(bookProvider).backendPill)),
              );
            },
            child: const Text('Save & test connection'),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Quote refresh'),
            subtitle: Text('${book.refreshSecs}s'),
            trailing: DropdownButton<int>(
              value: book.refreshSecs,
              items: const [15, 30, 45, 60]
                  .map((s) => DropdownMenuItem(value: s, child: Text('${s}s')))
                  .toList(),
              onChanged: (v) {
                if (v != null) ref.read(bookProvider.notifier).setRefresh(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Concentration cap'),
            subtitle: Text('${book.capPct.toStringAsFixed(0)}%'),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final c = TextEditingController(text: book.capPct.toString());
                final v = await showDialog<double>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Cap %'),
                    content: TextField(controller: c, keyboardType: TextInputType.number),
                    actions: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, double.tryParse(c.text)),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (v != null) ref.read(bookProvider.notifier).setCap(v);
              },
            ),
          ),
          ListTile(
            title: const Text('Export lots CSV'),
            trailing: const Icon(Icons.copy),
            onTap: () async {
              final csv = await ref.read(storeProvider).exportCsv();
              await Clipboard.setData(ClipboardData(text: csv));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
            },
          ),
          const Divider(),
          Text('Disclaimer', style: SA.mono(weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(kDisclaimer, style: const TextStyle(height: 1.4, color: SA.muted, fontSize: 12)),
          const SizedBox(height: 16),
          Text('Licences', style: SA.mono(weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Flutter (BSD). TradingAgents by Tauric Research (Apache-2.0) — research framework only. '
            'Yahoo Finance data used for personal research; not for resale. '
            'Sentient Alpha v1.0.0 · com.mate4tech.sentientalpha',
            style: SA.mono(size: 11, color: SA.muted),
          ),
        ],
      ),
    );
  }
}
