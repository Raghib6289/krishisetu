import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';

class FarmerChatbotSheet extends StatefulWidget {
  const FarmerChatbotSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FarmerChatbotSheet(),
    );
  }

  @override
  State<FarmerChatbotSheet> createState() => _FarmerChatbotSheetState();
}

class _ChatMessage {
  final String role; // 'user' or 'bot'
  final String text;
  final List<String> suggestedActions;

  _ChatMessage({
    required this.role,
    required this.text,
    this.suggestedActions = const [],
  });
}

class _FarmerChatbotSheetState extends State<FarmerChatbotSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<_ChatMessage> _messages = [
    _ChatMessage(
      role: 'bot',
      text: 'Namaste! I am **KrishiSetu Sahayak (कृषिसेतु सहायक)**.\n\n'
          'I am your AI assistant strictly bounded to the **KrishiSetu Platform**.\n'
          'Ask me about:\n'
          '• How to list produce & set competitive direct prices\n'
          '• Interpreting ARIMA 7-day demand & price forecasts\n'
          '• Razorpay Escrow payment guarantees\n'
          '• Grade A+/A/B quality standards\n'
          '• OR-Tools truck pickups & live tracking\n\n'
          '*(Off-topic non-KrishiSetu questions will be politely refused)*',
    ),
  ];

  final List<Map<String, String>> _quickQueries = [
    {
      'label': '🌾 List Crop Guide',
      'query': 'How do I list my crop on KrishiSetu to sell directly to buyers?',
    },
    {
      'label': '📈 Tomato Forecast',
      'query': 'What is the 7-day price forecast for Tomatoes and best time to sell?',
    },
    {
      'label': '💰 Escrow Payouts',
      'query': 'How does Razorpay Escrow guarantee my payment upon delivery?',
    },
    {
      'label': '⭐ Grade A+ Criteria',
      'query': 'What are the quality requirements for Grade A+ produce vs Grade A?',
    },
    {
      'label': '🚚 Pickup Logistics',
      'query': 'How does Google OR-Tools optimize driver pickup routes to my farm?',
    },
    {
      'label': '🛡️ Test Guardrail',
      'query': 'Who won the football world cup and what is python code?',
    },
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String query) async {
    final text = query.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: text));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Prepare rolling conversation history
    final history = _messages
        .where((m) => m.text.isNotEmpty)
        .take(6)
        .map((m) => {
              'role': m.role == 'user' ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    try {
      final res = await ApiClient().askFarmerChatbot(
        message: text,
        history: history,
      );

      final reply = res['reply'] as String? ?? 'No response received.';
      final suggested = (res['suggested_actions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          <String>[];

      setState(() {
        _messages.add(_ChatMessage(
          role: 'bot',
          text: reply,
          suggestedActions: suggested,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(
          role: 'bot',
          text: '⚠️ Network Error: Unable to reach KrishiSetu Sahayak service.',
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = (screenHeight * 0.85).clamp(400.0, 780.0);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: sheetHeight,
        ),
        child: Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // Header with Leaf Assistant Logo
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.06),
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0F3D24),
                            Color(0xFF1B5E20),
                            Color(0xFF2E7D32),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KrishiSetu Sahayak (कृषिसेतु सहायक)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(Icons.energy_savings_leaf_rounded,
                                  size: 13, color: Colors.green.shade800),
                              const SizedBox(width: 4),
                              Text(
                                'Agri AI Assistant • Strict Platform Guardrails',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Colors.grey),
                      tooltip: 'Reset Chat',
                      onPressed: () {
                        setState(() {
                          _messages.clear();
                          _messages.add(_ChatMessage(
                            role: 'bot',
                            text: 'Namaste! Chat reset. How can I assist you with KrishiSetu today?',
                          ));
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Quick Prompt Chips
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  scrollDirection: Axis.horizontal,
                  itemCount: _quickQueries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (ctx, idx) {
                    final item = _quickQueries[idx];
                    final isGuardrail = item['label']!.contains('Guardrail');
                    return ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: isGuardrail
                          ? Colors.red.shade50
                          : AppTheme.primaryGreen.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: isGuardrail
                            ? Colors.red.shade200
                            : AppTheme.primaryGreen.withValues(alpha: 0.3),
                      ),
                  label: Text(
                    item['label']!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isGuardrail
                          ? Colors.red.shade900
                          : AppTheme.primaryGreen,
                    ),
                  ),
                  onPressed: () => _sendMessage(item['query']!),
                );
              },
            ),
          ),

          // Message Stream
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (ctx, idx) {
                if (idx == _messages.length && _isLoading) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sahayak is thinking...',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[idx];
                final isUser = msg.role == 'user';

                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.82,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUser
                          ? AppTheme.primaryGreen
                          : const Color(0xFFF7FAF7),
                      border: isUser
                          ? null
                          : Border.all(color: const Color(0xFFE2EBE2)),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isUser ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (!isUser && msg.suggestedActions.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: msg.suggestedActions.map((act) {
                              return InkWell(
                                onTap: () => _sendMessage(act),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                        color: Colors.green.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '💡 $act',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.primaryGreen,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          )
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Input field
          Container(
            padding: EdgeInsets.only(
              left: 14,
              right: 8,
              top: 8,
              bottom: bottomInset > 0 ? bottomInset + 8 : 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendMessage(val),
                    decoration: InputDecoration(
                      hintText: 'Ask Sahayak about KrishiSetu...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide:
                            const BorderSide(color: AppTheme.primaryGreen),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: AppTheme.primaryGreen),
                  onPressed: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
  }
}
