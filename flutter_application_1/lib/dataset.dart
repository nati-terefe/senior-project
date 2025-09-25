import 'package:flutter/material.dart';

class DatasetScreen extends StatelessWidget {
  const DatasetScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _ScaffoldPad(
      title: 'Dataset Recorder',
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Record and label short clips'),
            subtitle: Text('Use consistent backgrounds and lighting'),
            trailing: FilledButton(onPressed: null, child: Text('New session')),
          ),
          Expanded(
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.fiber_manual_record),
                label: const Text('Start recording'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ]),
      );
}
