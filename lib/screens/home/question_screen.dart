import 'package:flutter/material.dart';

import 'headache_screen.dart';

/// Full DASS-21 questionnaire — 21 questions, one per page, scored 0–3.
class QuestionScreen extends StatefulWidget {
  const QuestionScreen({super.key});

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  // Standard DASS-21 questions (numbered 1-21 for the user).
  // Subscale mapping (0-based index):
  //   Depression : 2,4,9,12,15,16,20
  //   Anxiety    : 1,3,6,8,14,18,19
  //   Stress     : 0,5,7,10,11,13,17
  static const List<String> _questions = [
    'I found it hard to wind down.',                                                                          // 1  S
    'I was aware of dryness of my mouth.',                                                                    // 2  A
    "I couldn't seem to experience any positive feeling at all.",                                             // 3  D
    'I experienced breathing difficulty (e.g., excessively rapid breathing or breathlessness in the absence of physical exertion).', // 4  A
    'I found it difficult to work up the initiative to do things.',                                           // 5  D
    'I tended to over-react to situations.',                                                                  // 6  S
    'I experienced trembling (e.g., in the hands).',                                                         // 7  A
    'I felt that I was using a lot of nervous energy.',                                                       // 8  S
    'I was worried about situations in which I might panic and make a fool of myself.',                       // 9  A
    'I felt that I had nothing to look forward to.',                                                          // 10 D
    'I found myself getting agitated.',                                                                       // 11 S
    'I found it difficult to relax.',                                                                         // 12 S
    'I felt down-hearted and blue.',                                                                          // 13 D
    'I was intolerant of anything that kept me from getting on with what I was doing.',                       // 14 S
    'I felt I was close to panic.',                                                                           // 15 A
    'I was unable to become enthusiastic about anything.',                                                    // 16 D
    "I felt I wasn't worth much as a person.",                                                                // 17 D
    'I felt that I was rather touchy.',                                                                       // 18 S
    'I perspired noticeably (e.g., hands sweaty) in the absence of high temperatures or physical exertion.', // 19 A
    'I felt scared without any good reason.',                                                                 // 20 A
    'I felt that life was meaningless.',                                                                      // 21 D
  ];

  static const List<String> _options = [
    'Did not apply to me at all',
    'Applied to me to some degree',
    'Applied to me to a considerable degree',
    'Applied to me very much, or most of the time',
  ];

  final List<int> _answers = List.filled(21, -1);
  int _currentIndex = 0;

  void _goNext() {
    if (_currentIndex < 20) {
      setState(() => _currentIndex++);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HeadacheScreen(dass21Answers: List.from(_answers)),
        ),
      );
    }
  }

  void _goBack() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    } else {
      Navigator.pop(context);
    }
  }

  String _subscaleLabel(int index) {
    const depressionIdx = {2, 4, 9, 12, 15, 16, 20};
    const anxietyIdx = {1, 3, 6, 8, 14, 18, 19};
    if (depressionIdx.contains(index)) return 'Depression';
    if (anxietyIdx.contains(index)) return 'Anxiety';
    return 'Stress';
  }

  Color _subscaleColor(int index) {
    const depressionIdx = {2, 4, 9, 12, 15, 16, 20};
    const anxietyIdx = {1, 3, 6, 8, 14, 18, 19};
    if (depressionIdx.contains(index)) return const Color(0xFFF4C542);
    if (anxietyIdx.contains(index)) return const Color(0xFFE56A6A);
    return const Color(0xFF4EA8DE);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _answers[_currentIndex];
    final progress = (_currentIndex + 1) / 21;
    final label = _subscaleLabel(_currentIndex);
    final labelColor = _subscaleColor(_currentIndex);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _goBack(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_currentIndex + 1} of 21'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: labelColor.withAlpha(46),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: labelColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    '${_answers.where((a) => a != -1).length} / 21 answered',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                _questions[_currentIndex],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Over the past week…',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  itemCount: _options.length,
                  itemBuilder: (_, index) {
                    final isActive = selected == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: isActive ? Colors.deepPurple.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isActive ? Colors.deepPurple : Colors.grey.shade300,
                            width: isActive ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => setState(() => _answers[_currentIndex] = index),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isActive
                                      ? Colors.deepPurple
                                      : Colors.grey.shade200,
                                  child: Text(
                                    '$index',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isActive ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _options[index],
                                    style: TextStyle(
                                      fontWeight:
                                          isActive ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  const Icon(Icons.check_circle, color: Colors.deepPurple),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _goBack,
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selected == -1 ? null : _goNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_currentIndex == 20 ? 'Next: Headache' : 'Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
