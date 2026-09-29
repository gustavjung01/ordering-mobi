import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_failure.dart';
import '../data/customer_assistant_api.dart';

class CustomerAssistantScreen extends StatefulWidget {
  const CustomerAssistantScreen({
    super.key,
    required this.api,
  });

  final CustomerAssistantApi api;

  @override
  State<CustomerAssistantScreen> createState() =>
      _CustomerAssistantScreenState();
}

class _CustomerAssistantScreenState extends State<CustomerAssistantScreen> {
  static const _suggestions = <String>[
    'Có những loại lúa ve nào?',
    'Cách sử dụng lúa ve thế nào?',
    'Hướng dẫn tôi tìm sản phẩm và đặt hàng',
  ];

  final _controller = TextEditingController();
  final _messages = <_AssistantMessage>[
    const _AssistantMessage(
      role: _AssistantRole.assistant,
      text:
          'Chào Quý khách. Tôi có thể tư vấn sản phẩm, cách sử dụng và hướng dẫn thao tác trên ứng dụng. Việc chọn hàng và gửi đơn vẫn do Quý khách tự xác nhận.',
    ),
  ];
  late final String _sessionId = const Uuid().v4();
  AssistantCredit? _credit;
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggested]) async {
    if (_sending) return;
    final text = (suggested ?? _controller.text).trim();
    if (text.isEmpty) return;
    if (text.length > 1000) {
      setState(() {
        _error = 'Câu hỏi không được vượt quá 1.000 ký tự.';
      });
      return;
    }

    _controller.clear();
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(
        _AssistantMessage(role: _AssistantRole.user, text: text),
      );
    });

    try {
      final reply = await widget.api.send(
        sessionId: _sessionId,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _credit = reply.credit ?? _credit;
        _messages.add(
          _AssistantMessage(
            role: _AssistantRole.assistant,
            text: reply.text,
          ),
        );
      });
    } on ApiFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on Object {
      if (mounted) {
        setState(() {
          _error = 'Chưa thể kết nối hỗ trợ sản phẩm. Vui lòng thử lại.';
        });
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hỏi Hưng Phát')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Trợ lý chỉ tư vấn sản phẩm, cách sử dụng và hướng dẫn thao tác. Trợ lý không tự thêm giỏ hàng, tạo đơn hoặc gửi đơn.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_credit != null) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text(
                          'Hạn mức AI còn: \$${_credit!.remainingUsd} / \$${_credit!.limitUsd}',
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in _suggestions)
                        ActionChip(
                          label: Text(suggestion),
                          onPressed: _sending
                              ? null
                              : () => _send(suggestion),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  for (final message in _messages)
                    Align(
                      alignment: message.role == _AssistantRole.user
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 560),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: message.role == _AssistantRole.user
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(message.text),
                      ),
                    ),
                  if (_sending)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Đang tìm thông tin phù hợp…'),
                      ),
                    ),
                  if (_error != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_sending,
                      maxLength: 1000,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Nhập câu hỏi',
                        hintText:
                            'Hỏi về sản phẩm, cách dùng hoặc cách thao tác…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Gửi câu hỏi',
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AssistantRole { assistant, user }

class _AssistantMessage {
  const _AssistantMessage({
    required this.role,
    required this.text,
  });

  final _AssistantRole role;
  final String text;
}
