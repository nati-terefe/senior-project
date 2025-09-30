import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // In-memory store for now. Replace with your backend later.
  final List<VocabEntry> _entries = [];

  final _formKey = GlobalKey<FormState>();
  final _letter = TextEditingController();
  final _wordEn = TextEditingController();
  final _wordAm = TextEditingController();
  final _translit = TextEditingController();
  final _category = TextEditingController();
  final _videoUrl = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageName;
  bool _saving = false;

  @override
  void dispose() {
    _letter.dispose();
    _wordEn.dispose();
    _wordAm.dispose();
    _translit.dispose();
    _category.dispose();
    _videoUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true, // <-- needed for web
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _imageBytes = res.files.first.bytes;
        _imageName = res.files.first.name;
      });
    }
  }

  void _clearForm() {
    _letter.clear();
    _wordEn.clear();
    _wordAm.clear();
    _translit.clear();
    _category.clear();
    _videoUrl.clear();
    setState(() {
      _imageBytes = null;
      _imageName = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final entry = VocabEntry(
        letter: _letter.text.trim().toUpperCase(),
        wordEn: _wordEn.text.trim(),
        wordAm: _wordAm.text.trim(),
        transliteration:
            _translit.text.trim().isEmpty ? null : _translit.text.trim(),
        category:
            _category.text.trim().isEmpty ? 'General' : _category.text.trim(),
        videoUrl: _videoUrl.text.trim().isEmpty ? null : _videoUrl.text.trim(),
        imageBytes: _imageBytes,
        createdAt: DateTime.now(),
      );

      setState(() => _entries.insert(0, entry));
      _clearForm();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vocabulary item added')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  void _delete(int index) {
    setState(() => _entries.removeAt(index));
  }

  void _exportAsJson() {
    final data = _entries.map((e) => e.toJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    // For now just print; you can also write to file or upload to backend.
    debugPrint(jsonStr);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exported to console (JSON)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin • Vocabulary',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall!
                  .copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          // Form card
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            controller: _letter,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Letter',
                              hintText: 'A, B, C…',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final t = v.trim().toUpperCase();
                              if (!RegExp(r'^[A-Z]$').hasMatch(t)) {
                                return 'One A–Z letter';
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextFormField(
                            controller: _wordEn,
                            decoration: const InputDecoration(
                              labelText: 'English word',
                              hintText: 'e.g., Hello',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextFormField(
                            controller: _wordAm,
                            decoration: const InputDecoration(
                              labelText: 'Amharic word',
                              hintText: 'e.g., ሰላም',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextFormField(
                            controller: _translit,
                            decoration: const InputDecoration(
                              labelText: 'Transliteration (optional)',
                              hintText: 'e.g., selam',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            controller: _category,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              hintText: 'e.g., Greetings',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 320,
                          child: TextFormField(
                            controller: _videoUrl,
                            decoration: const InputDecoration(
                              labelText: 'Video URL (optional)',
                              hintText: 'https://youtu.be/…',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Image picker & preview
                    Row(
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Upload image'),
                        ),
                        const SizedBox(width: 12),
                        if (_imageBytes != null)
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: cs.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.memory(
                                    _imageBytes!,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    _imageName ?? 'image',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () => setState(() =>
                                      {_imageBytes = null, _imageName = null}),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.save),
                          label: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Toolbar for list
          Row(
            children: [
              Text('Recently added',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _entries.isEmpty ? null : _exportAsJson,
                icon: const Icon(Icons.upload),
                label: const Text('Export JSON'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Entries list
          Expanded(
            child: _entries.isEmpty
                ? const Center(child: Text('No entries yet'))
                : ListView.separated(
                    itemCount: _entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(e.letter),
                        ),
                        title: Text('${e.wordEn} • ${e.wordAm}'),
                        subtitle: Text([
                          if (e.category != null) e.category,
                          if (e.transliteration != null)
                            '(${e.transliteration})',
                          if (e.videoUrl != null) 'video',
                        ].whereType<String>().join('  •  ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (e.imageBytes != null)
                              Tooltip(
                                message: 'Image attached',
                                child: Icon(Icons.image_outlined,
                                    color: cs.primary),
                              ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _delete(i),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class VocabEntry {
  final String letter;
  final String wordEn;
  final String wordAm;
  final String? transliteration;
  final String? category;
  final String? videoUrl;
  final Uint8List? imageBytes;
  final DateTime createdAt;

  VocabEntry({
    required this.letter,
    required this.wordEn,
    required this.wordAm,
    this.transliteration,
    this.category,
    this.videoUrl,
    this.imageBytes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'letter': letter,
        'wordEn': wordEn,
        'wordAm': wordAm,
        'transliteration': transliteration,
        'category': category,
        'videoUrl': videoUrl,
        'imageBase64': imageBytes == null ? null : base64Encode(imageBytes!),
        'createdAt': createdAt.toIso8601String(),
      };
}
