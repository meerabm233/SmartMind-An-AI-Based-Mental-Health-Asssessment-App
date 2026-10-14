import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final List<_Message> _messages;
  bool _isReplying = false;

  @override
  void initState() {
    super.initState();
    final userName = AuthService.currentUser?.displayName ?? 'there';
    _messages = [
      _Message(
        text:
            'Hi $userName! I\'m your SmartMind AI assistant. I can help you with:\n\n'
            '- Stress & anxiety management\n'
            '- Mood and depression support\n'
            '- Sleep improvement tips\n'
            '- Headache relief strategies\n'
            '- Breathing & relaxation exercises\n'
            '- Understanding your DASS-21 results\n\n'
            'How are you feeling today?',
        isMe: false,
        time: _formatNow(),
      ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isReplying) return;

    setState(() {
      _messages.add(_Message(text: text, isMe: true, time: _formatNow()));
      _controller.clear();
      _isReplying = true;
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 800));
    final reply = _buildAiReply(text);

    if (!mounted) return;
    setState(() {
      _messages.add(_Message(text: reply, isMe: false, time: _formatNow()));
      _isReplying = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  String _buildAiReply(String input) {
    final lower = input.toLowerCase();

    // Greetings
    if (RegExp(r'\b(hi|hello|hey|assalam|salam|good morning|good evening|good afternoon)\b')
        .hasMatch(lower)) {
      return 'Hello! I\'m glad you\'re here. How are you feeling right now? '
          'You can tell me about your mood, stress levels, sleep, or anything on your mind.';
    }

    // How are you / I'm fine
    if (RegExp(r'\b(how are you|what about you)\b').hasMatch(lower)) {
      return 'Thank you for asking! I\'m here and ready to help you. '
          'More importantly, how are YOU doing today? Is there anything specific you\'d like to talk about?';
    }

    if (RegExp(r"\b(i'?m (fine|good|okay|great|ok)|doing (well|good|fine|great))\b")
        .hasMatch(lower)) {
      return 'That\'s wonderful to hear! Maintaining good mental health is just as important as physical health. '
          'Would you like some tips to keep your positive momentum going, or is there anything else I can help with?';
    }

    // Crisis / Suicidal thoughts
    if (RegExp(r"\b(suicid|kill myself|end my life|want to die|self.?harm|hurting myself|don'?t want to live)\b")
        .hasMatch(lower)) {
      return 'I\'m really concerned about what you\'re sharing. Please know that you matter and help is available.\n\n'
          'Please reach out immediately:\n'
          '- Pakistan: Umang Helpline 0311-7786264\n'
          '- International: Crisis Text Line - Text HOME to 741741\n'
          '- USA: 988 Suicide & Crisis Lifeline\n'
          '- UK: Samaritans 116 123\n\n'
          'You\'re not alone in this. Please talk to someone you trust right away.';
    }

    // Stress management
    if (RegExp(r'\b(stress|stressed|stressful|overwhelm|pressure|burnout|burn.?out|overwork)\b')
        .hasMatch(lower)) {
      return 'I understand you\'re feeling stressed. Here are some evidence-based strategies:\n\n'
          '1. **4-7-8 Breathing**: Inhale for 4 sec, hold for 7 sec, exhale for 8 sec. Repeat 4 times.\n\n'
          '2. **Progressive Muscle Relaxation**: Tense each muscle group for 5 seconds, then release. Start from your toes and work up.\n\n'
          '3. **Time Management**: Break tasks into 25-minute focused blocks (Pomodoro technique) with 5-minute breaks.\n\n'
          '4. **Physical Activity**: Even a 10-minute walk can reduce stress hormones significantly.\n\n'
          '5. **Limit Triggers**: Identify your top 3 stressors and take one small step to address each.\n\n'
          'Would you like me to guide you through a specific relaxation exercise?';
    }

    // Anxiety
    if (RegExp(r'\b(anxi|anxious|nervous|worry|worrie|panic|fear|scared|phobia|restless|uneasy|on edge)\b')
        .hasMatch(lower)) {
      return 'Anxiety can be really challenging. Here are some techniques that help:\n\n'
          '1. **Grounding (5-4-3-2-1)**: Name 5 things you see, 4 you can touch, 3 you hear, 2 you smell, 1 you taste.\n\n'
          '2. **Box Breathing**: Inhale 4 sec, hold 4 sec, exhale 4 sec, hold 4 sec. This activates your parasympathetic nervous system.\n\n'
          '3. **Challenge Anxious Thoughts**: Ask yourself — "Is this thought based on fact or fear? What\'s the most realistic outcome?"\n\n'
          '4. **Reduce Caffeine**: Caffeine can amplify anxiety symptoms significantly.\n\n'
          '5. **Journaling**: Write down your worries. Research shows this can reduce their intensity.\n\n'
          'If anxiety is affecting your daily life, consider speaking with a mental health professional. Would you like to try a breathing exercise now?';
    }

    // Depression / Sadness
    if (RegExp(r"\b(depress|sad|unhappy|hopeless|empty|lonely|alone|worthless|unmotivated|no motivation|can'?t cope|miserable|down|blue|low mood)\b")
        .hasMatch(lower)) {
      return 'I hear you, and I\'m glad you\'re reaching out. Depression and persistent sadness are real and valid. Here\'s what can help:\n\n'
          '1. **Behavioural Activation**: Do one small pleasurable activity today — even a 5-minute walk or listening to a favourite song.\n\n'
          '2. **Social Connection**: Reach out to one person today, even a short text message counts.\n\n'
          '3. **Routine**: Try to maintain regular sleep, meals, and activity times. Structure helps stabilize mood.\n\n'
          '4. **Gratitude Practice**: Write down 3 things you\'re grateful for, no matter how small.\n\n'
          '5. **Sunlight Exposure**: Spend 15-20 minutes in natural light, especially in the morning.\n\n'
          'Remember: seeking help is a sign of strength, not weakness. If these feelings persist for more than 2 weeks, please consider talking to a professional.';
    }

    // Sleep / Insomnia
    if (RegExp(r"\b(sleep|insomnia|can'?t sleep|trouble sleeping|wake up|nightmar|restless night|tired|fatigue|exhausted)\b")
        .hasMatch(lower)) {
      return 'Sleep is crucial for mental health. Here\'s a science-backed sleep hygiene routine:\n\n'
          '1. **Consistent Schedule**: Go to bed and wake up at the same time daily, even weekends.\n\n'
          '2. **Screen-Free Zone**: Stop screens 30-60 minutes before bed. Blue light suppresses melatonin.\n\n'
          '3. **Cool & Dark Room**: Keep your bedroom cool (18-20 C), dark, and quiet.\n\n'
          '4. **Wind-Down Ritual**: Try reading, gentle stretching, or slow breathing before bed.\n\n'
          '5. **Avoid Stimulants**: No caffeine after 2 PM, and limit heavy meals before bed.\n\n'
          '6. **4-7-8 Breathing in Bed**: This technique naturally induces relaxation and sleep.\n\n'
          'If sleep problems persist for more than 3 weeks, consult a healthcare provider.';
    }

    // Headache
    if (RegExp(r'\b(headache|migraine|head pain|head hurt|head ache|cluster headache|tension headache)\b')
        .hasMatch(lower)) {
      return 'Headaches can be closely linked to stress and mental health. Here\'s how to manage them:\n\n'
          '**For Tension Headaches:**\n'
          '- Apply a warm or cold compress to your forehead\n'
          '- Gently massage your temples and neck\n'
          '- Check your posture — sit upright with shoulders relaxed\n'
          '- Stay hydrated (aim for 8 glasses of water daily)\n\n'
          '**For Migraines:**\n'
          '- Rest in a dark, quiet room\n'
          '- Keep a headache diary to identify triggers\n'
          '- Avoid known triggers (certain foods, bright lights, dehydration)\n\n'
          '**General Tips:**\n'
          '- Regular sleep schedule\n'
          '- Regular meals — don\'t skip meals\n'
          '- Manage stress with relaxation techniques\n\n'
          'If headaches are frequent or severe, please consult a neurologist. You can find doctors in the Doctors tab.';
    }

    // Breathing exercises
    if (RegExp(r'\b(breath|breathing|breathe|inhale|exhale)\b').hasMatch(lower)) {
      return 'Let\'s do a calming breathing exercise together:\n\n'
          '**Box Breathing (Navy SEAL technique):**\n\n'
          '1. Sit comfortably and close your eyes\n'
          '2. Inhale slowly through your nose for 4 seconds\n'
          '3. Hold your breath for 4 seconds\n'
          '4. Exhale slowly through your mouth for 4 seconds\n'
          '5. Hold for 4 seconds\n'
          '6. Repeat 4-6 times\n\n'
          '**4-7-8 Breathing (for sleep & deep relaxation):**\n\n'
          '1. Inhale through nose for 4 seconds\n'
          '2. Hold for 7 seconds\n'
          '3. Exhale through mouth for 8 seconds\n'
          '4. Repeat 3-4 cycles\n\n'
          'These techniques activate your body\'s natural relaxation response. Try them whenever you feel tense or anxious.';
    }

    // Meditation / Mindfulness
    if (RegExp(r'\b(meditat|mindful|calm|relax|peace|grounding|ground me|center)\b')
        .hasMatch(lower)) {
      return 'Mindfulness and meditation are powerful tools for mental wellbeing:\n\n'
          '**Quick 5-Minute Mindfulness Exercise:**\n\n'
          '1. Sit quietly and focus on your breathing\n'
          '2. Notice each inhale and exhale without changing it\n'
          '3. When your mind wanders (it will!), gently bring focus back\n'
          '4. Notice sounds, sensations, and thoughts without judging them\n'
          '5. End by taking 3 deep, intentional breaths\n\n'
          '**Body Scan (for tension release):**\n'
          '- Start at your toes and slowly move attention up through your body\n'
          '- Notice where you hold tension\n'
          '- Breathe into those areas and consciously relax them\n\n'
          'Even 5 minutes daily can make a significant difference. Consistency matters more than duration.';
    }

    // DASS-21 / Assessment
    if (RegExp(r'\b(dass|assessment|score|result|test|questionnaire|evaluation)\b')
        .hasMatch(lower)) {
      return 'The DASS-21 assessment measures three areas:\n\n'
          '**Depression**: Feelings of hopelessness, lack of interest, low self-worth\n'
          '**Anxiety**: Physical arousal, panic, fear\n'
          '**Stress**: Difficulty relaxing, nervous tension, irritability\n\n'
          'Each subscale has severity levels: Normal, Mild, Moderate, Severe, Extremely Severe.\n\n'
          'Your scores help us provide personalized recommendations. You can:\n'
          '- Take the assessment from the Home screen\n'
          '- View your results in the Progress tab\n'
          '- Track changes over time\n\n'
          'Remember, the DASS-21 is a screening tool, not a diagnosis. For clinical evaluation, please consult a mental health professional.';
    }

    // Exercise / Physical activity
    if (RegExp(r'\b(exercis|workout|gym|yoga|walk|run|physical|active|sport|fitness)\b')
        .hasMatch(lower)) {
      return 'Exercise is one of the most effective natural treatments for mental health:\n\n'
          '- **30 minutes of moderate exercise** can reduce anxiety and depression symptoms by 25-50%\n'
          '- **Walking** for just 10 minutes can improve mood for up to 2 hours\n'
          '- **Yoga** combines physical movement, breathing, and mindfulness\n\n'
          '**Start Small:**\n'
          '- 10-minute morning walk\n'
          '- Gentle stretching breaks every hour\n'
          '- Take stairs instead of elevator\n\n'
          '**For Maximum Benefit:**\n'
          '- Aim for 150 minutes moderate exercise per week\n'
          '- Mix cardio and strength training\n'
          '- Exercise outdoors when possible for extra mood boost\n\n'
          'The best exercise is one you enjoy and can stick with!';
    }

    // Anger management
    if (RegExp(r'\b(angry|anger|rage|furious|irritat|frustrated|frustration|mad|temper)\b')
        .hasMatch(lower)) {
      return 'Feeling angry is natural. Here\'s how to manage it constructively:\n\n'
          '1. **Pause**: When anger rises, count to 10 before responding. Remove yourself from the situation if needed.\n\n'
          '2. **Deep Breathing**: Slow, deep breaths help your body\'s fight-or-flight response calm down.\n\n'
          '3. **Express, Don\'t Suppress**: Use "I feel..." statements instead of blaming. E.g., "I feel frustrated when..." instead of "You always..."\n\n'
          '4. **Physical Release**: Channel energy into exercise, walking, or even squeezing a stress ball.\n\n'
          '5. **Identify Triggers**: Keep a brief anger log — what happened, what you felt, and what you did. Patterns will emerge.\n\n'
          'Chronic anger can affect your health. If it\'s interfering with relationships or daily life, consider anger management counseling.';
    }

    // Relationships
    if (RegExp(r'\b(relationship|partner|friend|family|argument|fight|conflict|marriage|breakup|break.?up|divorce|love)\b')
        .hasMatch(lower)) {
      return 'Relationships significantly impact our mental health. Here are some helpful approaches:\n\n'
          '1. **Active Listening**: Give full attention, reflect back what you hear before responding.\n\n'
          '2. **Set Boundaries**: It\'s okay to say no. Healthy boundaries protect your wellbeing.\n\n'
          '3. **Communicate Openly**: Share your feelings using "I" statements rather than accusations.\n\n'
          '4. **Quality Time**: Prioritize meaningful connection over screen time.\n\n'
          '5. **Self-Care First**: You can\'t pour from an empty cup. Take care of yourself to be better for others.\n\n'
          'If you\'re going through a difficult relationship situation, talking to a counselor can provide valuable perspective and coping strategies.';
    }

    // Self-esteem / Confidence
    if (RegExp(r'\b(self.?esteem|confiden|self.?worth|insecur|ugly|hate myself|not good enough|failure|loser)\b')
        .hasMatch(lower)) {
      return 'Building self-esteem is a journey. Here are evidence-based strategies:\n\n'
          '1. **Challenge Negative Self-Talk**: Replace "I can\'t" with "I\'m learning." Notice and question harsh inner critic.\n\n'
          '2. **Daily Affirmations**: "I am worthy of good things. I am making progress." Say them even when you don\'t fully believe them yet.\n\n'
          '3. **Small Wins**: Set achievable daily goals and celebrate completing them.\n\n'
          '4. **Limit Comparison**: Especially on social media. Everyone shows their highlight reel, not their struggles.\n\n'
          '5. **Self-Compassion**: Treat yourself as you would treat a good friend — with kindness and understanding.\n\n'
          'Remember: Your value is not determined by your productivity, appearance, or others\' opinions. You are enough as you are.';
    }

    // Work / Study stress
    if (RegExp(r'\b(work|job|study|exam|school|university|college|assignment|deadline|boss|career)\b')
        .hasMatch(lower)) {
      return 'Work/study-related stress is very common. Here\'s how to manage it:\n\n'
          '1. **Prioritize Tasks**: Use the Eisenhower Matrix — categorize tasks by urgency and importance.\n\n'
          '2. **Break It Down**: Large tasks feel overwhelming. Break them into smaller, manageable steps.\n\n'
          '3. **Take Breaks**: The Pomodoro Technique — 25 min work, 5 min break — improves focus and reduces fatigue.\n\n'
          '4. **Set Boundaries**: Define clear work/study hours. Protect your rest time.\n\n'
          '5. **Ask for Help**: It\'s okay to ask colleagues, classmates, or supervisors for support.\n\n'
          '6. **Celebrate Progress**: Acknowledge what you\'ve accomplished rather than focusing only on what\'s left.\n\n'
          'If work/study pressure is affecting your mental health significantly, consider speaking with a counselor.';
    }

    // Eating / Diet
    if (RegExp(r'\b(eat|diet|food|nutrition|appetite|weight|hungry|binge|eating disorder)\b')
        .hasMatch(lower)) {
      return 'Nutrition and mental health are closely connected:\n\n'
          '**Brain-Boosting Foods:**\n'
          '- Omega-3 rich foods (fish, walnuts, flaxseed)\n'
          '- Whole grains for steady energy\n'
          '- Fruits and vegetables (especially berries and leafy greens)\n'
          '- Fermented foods for gut health\n\n'
          '**Habits to Build:**\n'
          '- Eat regular meals — don\'t skip meals\n'
          '- Stay hydrated — dehydration affects mood\n'
          '- Limit processed sugar and caffeine\n'
          '- Practice mindful eating — eat slowly, without screens\n\n'
          'If you\'re experiencing significant appetite changes, binge eating, or restrictive eating, please consult a healthcare professional.';
    }

    // Thank you
    if (RegExp(r'\b(thank|thanks|thx|appreciate|helpful|great advice)\b')
        .hasMatch(lower)) {
      return 'You\'re welcome! I\'m always here to support you. Remember:\n\n'
          '- Take your DASS-21 assessment regularly to track your progress\n'
          '- Log headaches to identify patterns\n'
          '- Reach out to professional doctors in the app if needed\n\n'
          'Is there anything else I can help you with?';
    }

    // Goodbye
    if (RegExp(r'\b(bye|goodbye|good night|see you|take care|gotta go|leaving)\b')
        .hasMatch(lower)) {
      return 'Take care of yourself! Remember:\n\n'
          '- You can come back and chat anytime\n'
          '- Practice one relaxation technique today\n'
          '- Be kind to yourself\n\n'
          'Wishing you a peaceful day! See you soon.';
    }

    // Tips / Help / Suggestions
    if (RegExp(r'\b(tip|advice|suggest|help|recommend|what should|what can)\b')
        .hasMatch(lower)) {
      return 'Here are some daily mental wellness tips:\n\n'
          '1. **Morning Routine**: Start with 5 minutes of deep breathing or stretching.\n\n'
          '2. **Hydrate**: Drink water first thing — dehydration affects mood and focus.\n\n'
          '3. **Move Your Body**: Even a 10-minute walk helps regulate mood.\n\n'
          '4. **Connect**: Reach out to someone — a friend, family member, or colleague.\n\n'
          '5. **Gratitude**: Before bed, write 3 things that went well today.\n\n'
          '6. **Limit Screen Time**: Take regular breaks from social media.\n\n'
          '7. **Sleep**: Aim for 7-9 hours of quality sleep.\n\n'
          'Would you like detailed guidance on any of these areas?';
    }

    // Feelings / Emotions
    if (RegExp(r'\b(feel|feeling|emotion|mood|crying|cry|tears|hurt|pain|suffering)\b')
        .hasMatch(lower)) {
      return 'Thank you for sharing how you feel. Your emotions are valid and important.\n\n'
          'Here\'s a helpful approach to processing emotions:\n\n'
          '1. **Name It**: Simply identifying the emotion ("I feel anxious" or "I feel sad") reduces its intensity.\n\n'
          '2. **Accept It**: Don\'t judge the feeling. All emotions serve a purpose.\n\n'
          '3. **Explore It**: Ask yourself — "What triggered this? What do I need right now?"\n\n'
          '4. **Express It**: Talk to someone, write in a journal, or express through art.\n\n'
          '5. **Respond**: Choose a healthy response — a walk, deep breathing, or reaching out for support.\n\n'
          'Would you like to tell me more about what you\'re experiencing?';
    }

    // Default response
    return 'Thank you for sharing that with me. I\'m here to support your mental wellbeing.\n\n'
        'I can help you with:\n'
        '- **Stress & anxiety** management techniques\n'
        '- **Mood & depression** support\n'
        '- **Sleep** improvement tips\n'
        '- **Headache** relief strategies\n'
        '- **Breathing & meditation** exercises\n'
        '- **Self-esteem** building\n'
        '- **Work/study** stress management\n'
        '- Understanding your **DASS-21 results**\n\n'
        'Try telling me how you\'re feeling, or ask about any of these topics!';
  }

  static String _formatNow() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartMind AI'), actions: const [
        Padding(
          padding: EdgeInsets.only(right: 12),
          child: Icon(Icons.more_vert),
        )
      ]),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child:
                _ChatList(messages: _messages, scrollController: _scrollController),
          ),
          if (_isReplying)
            const Padding(
              padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SmartMind AI is typing...',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    onPressed: _sendMessage,
                    color: Colors.white,
                    icon: const Icon(Icons.send),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _Message {
  const _Message({required this.text, required this.isMe, required this.time});

  final String text;
  final bool isMe;
  final String time;
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.messages, required this.scrollController});

  final List<_Message> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      children: messages
          .map((m) => _MsgBubble(text: m.text, isMe: m.isMe, time: m.time))
          .toList(),
    );
  }
}

class _MsgBubble extends StatelessWidget {
  const _MsgBubble(
      {required this.text, required this.isMe, required this.time});

  final String text;
  final bool isMe;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFEAE7FF) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            const SizedBox(height: 6),
            Text(time,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
