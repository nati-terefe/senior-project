import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vocab = FirebaseFirestore.instance.collection('vocab');

    return _ScaffoldPad(
      title: 'Vocabulary',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: vocab.orderBy('createdAt').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No vocabulary added yet.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final crossAxisCount = w < 600 ? 2 : (w < 1000 ? 3 : 4);

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data();
                  final text = (data['text'] ?? '').toString();
                  Uint8List? imgBytes;
                  final b64 = (data['imageBase64'] ?? '').toString();
                  if (b64.isNotEmpty) {
                    try {
                      imgBytes = base64Decode(b64);
                    } catch (_) {}
                  }

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        if (imgBytes != null) {
                          _showFlashcard(context, text, imgBytes);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: imgBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        imgBytes,
                                        fit: BoxFit.contain,
                                        width: double.infinity,
                                      ),
                                    )
                                  : const Icon(Icons.image, size: 48),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              text,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

/* -------------------- Flashcard Dialog -------------------- */

void _showFlashcard(BuildContext context, String text, Uint8List imgBytes) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWeb = constraints.maxWidth > 600;
            final maxImgHeight = isWeb ? 400.0 : 300.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close (X) button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),

                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    imgBytes,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: maxImgHeight,
                  ),
                ),

                const SizedBox(height: 16),

                // Text (only at bottom)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    text,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

/* -------------------- Shared scaffold wrapper -------------------- */

class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall!
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ]),
      );
}
