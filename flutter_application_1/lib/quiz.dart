import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _qIndex = 0;
  int? _picked;
  int _score = 0;
  bool _showAnswer = false;
  bool _finished = false;

  // randomization seed per session
  final int _seed = DateTime.now().millisecondsSinceEpoch;
  late final Random _rng = Random(_seed);
  List<QueryDocumentSnapshot<Map<String, dynamic>>>? _sessionOrder;

  // SAFE restart
  void _reset(int total) {
    Future.microtask(() {
      if (!mounted) return;
      setState(() {
        _qIndex = 0;
        _picked = null;
        _score = 0;
        _showAnswer = false;
        _finished = false;
      });
    });
  }

  void _pick(int i, int correct) {
    if (_showAnswer || _finished) return;
    setState(() {
      _picked = i;
      _showAnswer = true;
      if (i == correct) _score++;
    });
  }

  Future<void> _saveLastResult(int score, int total) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meta')
        .doc('quiz');

    await ref.set({
      'lastScore': score,
      'lastTotal': total,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _next(int total) {
    if (_qIndex + 1 < total) {
      setState(() {
        _qIndex++;
        _picked = null;
        _showAnswer = false;
      });
    } else {
      setState(() => _finished = true);
      _saveLastResult(_score, total);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizzes = FirebaseFirestore.instance.collection('quizzes');

    final user = FirebaseAuth.instance.currentUser;

    return _ScaffoldPad(
      title: 'Quiz',
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: quizzes.orderBy('createdAt').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No quiz questions yet'),
              ),
            );
          }

          // randomize order once per session
          _sessionOrder ??= [...docs]..shuffle(_rng);
          final total = _sessionOrder!.length;
          final idx = _qIndex.clamp(0, total - 1);
          final data = _sessionOrder![idx].data();

          Uint8List? imgBytes;
          final b64 = (data['imageBase64'] ?? '').toString();
          if (b64.isNotEmpty) {
            try {
              imgBytes = base64Decode(b64);
            } catch (_) {}
          }

          final rawChoices = (data['choices'] as List?) ?? const [];
          final choices = rawChoices.map((e) => e.toString()).toList();
          while (choices.length < 4) choices.add('—');
          final correct = (data['correctIndex'] ?? 0) as int;
          final progress = (idx + 1) / total;

          return LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final isPhone = w < 560;
              final maxCardW = isPhone ? w : 720.0;

              final card = Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user != null) _LastResultBanner(user: user),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'What does this sign mean?',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text('${idx + 1}/$total',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 16),

                      // Image
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: kIsWeb ? 220 : 320,
                          maxWidth: double.infinity,
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceVariant
                                .withOpacity(.6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: imgBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.memory(
                                    imgBytes,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    height: double.infinity,
                                    gaplessPlayback: true,
                                  ),
                                )
                              : Icon(Icons.image_not_supported,
                                  size: isPhone ? 56 : 72),
                        ),
                      ),

                      const SizedBox(height: 16),

                      _ChoicesGrid(
                        choices: choices,
                        picked: _picked,
                        correct: correct,
                        showAnswer: _showAnswer || _finished,
                        onPick: (i) => _pick(i, correct),
                      ),
                      const SizedBox(height: 12),

                      if (_finished)
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Done! Score: $_score / $total',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _reset(total),
                              icon: const Icon(Icons.replay),
                              label: const Text('Restart'),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Text(
                              _showAnswer
                                  ? (_picked == correct
                                      ? 'Correct!'
                                      : 'Not quite.')
                                  : 'Pick an answer',
                              style: TextStyle(
                                color: _showAnswer
                                    ? (_picked == correct
                                        ? Colors.green
                                        : Theme.of(context).colorScheme.error)
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            if (_showAnswer)
                              FilledButton.icon(
                                onPressed: () => _next(total),
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text('Next'),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              );

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardW),
                  child: SingleChildScrollView(child: card),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* -------------------- Choices grid -------------------- */
class _ChoicesGrid extends StatelessWidget {
  const _ChoicesGrid({
    required this.choices,
    required this.picked,
    required this.correct,
    required this.showAnswer,
    required this.onPick,
  });

  final List<String> choices;
  final int? picked;
  final int correct;
  final bool showAnswer;
  final void Function(int index) onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final isPhone = c.maxWidth < 560;
      final crossAxisCount = isPhone ? 2 : 4;
      final spacing = 12.0;

      Color bg(int i) {
        if (!showAnswer) return Theme.of(context).colorScheme.surface;
        if (i == correct) return Colors.green.withOpacity(.14);
        if (picked == i && picked != correct) {
          return Theme.of(context).colorScheme.error.withOpacity(.12);
        }
        return Theme.of(context).colorScheme.surface;
      }

      Color fg(int i) {
        if (!showAnswer) return Theme.of(context).colorScheme.onSurface;
        if (i == correct) return Colors.green.shade800;
        if (picked == i && picked != correct) {
          return Theme.of(context).colorScheme.error;
        }
        return Theme.of(context).colorScheme.onSurface;
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: isPhone ? 3.0 : 3.6,
        ),
        itemBuilder: (_, i) {
          return Material(
            color: bg(i),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: showAnswer ? null : () => onPick(i),
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Text(
                    choices[i],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: fg(i),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/* -------------------- Last result banner -------------------- */
class _LastResultBanner extends StatelessWidget {
  const _LastResultBanner({required this.user, super.key});
  final User user;

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meta')
        .doc('quiz');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        final data = snap.data?.data();
        final cs = Theme.of(context).colorScheme;

        BoxDecoration deco() => BoxDecoration(
              color: cs.surfaceVariant.withOpacity(.6),
              borderRadius: BorderRadius.circular(12),
            );

        if (data == null) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: deco(),
            child: Row(
              children: const [
                Icon(Icons.emoji_events_outlined),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No previous quiz result yet — take your first quiz and your score will appear here.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        final int? lastScore = (data['lastScore'] as num?)?.toInt();
        final int? lastTotal = (data['lastTotal'] as num?)?.toInt();
        final ts = data['updatedAt'];
        String when = '';
        if (ts is Timestamp) {
          final dt = ts.toDate();
          when =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: deco(),
          child: Row(
            children: [
              const Icon(Icons.history_edu_outlined),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Last result: $lastScore / $lastTotal${when.isEmpty ? '' : ' • $when'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* -------------------- Shared scaffold -------------------- */
class _ScaffoldPad extends StatelessWidget {
  const _ScaffoldPad({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ),
      );
}
