import 'package:flutter/material.dart';

import '../data/lines.dart';

class LinesScreen extends StatelessWidget {
  const LinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('ঢাকা মেট্রো রেল লাইন',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (final line in allLines)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: line.operational
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                foregroundColor: line.operational
                    ? scheme.onPrimary
                    : scheme.onSurfaceVariant,
                child: const Icon(Icons.train),
              ),
              title: Text(line.nameBn),
              subtitle: Text(line.routeBn),
              trailing: Chip(
                label: Text(line.operational ? 'চালু' : 'আসছে'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
      ],
    );
  }
}
