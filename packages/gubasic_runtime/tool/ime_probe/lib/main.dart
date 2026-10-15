import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Records what a real input method sends to a Flutter TextField: every
/// value (text, composing range, selection), key, focus change and click,
/// for four Korean typing scenarios. "Save" downloads one JSON file; the
/// files become test input for gubasic_runtime's TextBox
/// (test/ime_logs/).
///
///     flutter run -d chrome --release
void main() => runApp(const MaterialApp(home: Probe()));

class Scenario {
  const Scenario(this.id, this.title, this.steps, {this.withButtons = false});

  final String id;
  final String title;
  final String steps;
  final bool withButtons;
}

const scenarios = [
  Scenario(
    'dokkaebi',
    '1. 도깨비불: 갈가',
    '칸을 누르고 ㄱ ㅏ ㄹ ㄱ ㅏ (키: r k f r k)를 칩니다. 스페이스는 치지 않습니다.',
  ),
  Scenario(
    'double_final',
    '2. 겹받침: 닭 값',
    'ㄷ ㅏ ㄹ ㄱ (e k f r), 스페이스, ㄱ ㅏ ㅂ ㅅ (r k q t), 스페이스를 칩니다.',
  ),
  Scenario(
    'backspace',
    '3. 조합 중 백스페이스: 한 → 하',
    'ㅎ ㅏ ㄴ (g k s)을 치고 백스페이스를 한 번 누릅니다. 스페이스는 치지 않습니다.',
  ),
  Scenario(
    'click',
    '4. 조합 중 클릭: 한글',
    'ㅎ ㅏ ㄴ ㄱ ㅡ ㄹ (g k s r m f)을 스페이스 없이 치고 바로 버튼 A를 누릅니다. '
        '"다시"를 누른 뒤 같은 것을 치고 이번에는 버튼 B를 누릅니다.',
    withButtons: true,
  ),
];

class Probe extends StatefulWidget {
  const Probe({super.key});

  @override
  State<Probe> createState() => _ProbeState();
}

class _ProbeState extends State<Probe> {
  final _logs = {for (final s in scenarios) s.id: <Map<String, Object?>>[]};
  final _controllers = {
    for (final s in scenarios) s.id: TextEditingController(),
  };
  final _focus = {for (final s in scenarios) s.id: FocusNode()};
  final _buttonFocus = FocusNode();
  final _clock = Stopwatch()..start();
  String? _active;

  @override
  void initState() {
    super.initState();
    for (final s in scenarios) {
      final c = _controllers[s.id]!;
      c.addListener(() => _add(s.id, {'kind': 'value', ..._value(c.value)}));
      _focus[s.id]!.addListener(() {
        if (_focus[s.id]!.hasFocus) _active = s.id;
        _add(s.id, {'kind': 'focus', 'hasFocus': _focus[s.id]!.hasFocus});
      });
    }
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    final id = _active;
    if (id != null) {
      _add(id, {
        'kind': switch (e) {
          KeyDownEvent() => 'keyDown',
          KeyUpEvent() => 'keyUp',
          _ => 'keyRepeat',
        },
        'key': e.logicalKey.keyLabel,
        'physical': e.physicalKey.debugName,
        'character': e.character,
      });
    }
    return false;
  }

  Map<String, Object?> _value(TextEditingValue v) => {
    'text': v.text,
    'codes': [
      for (final r in v.text.runes)
        'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}',
    ],
    'composing': [v.composing.start, v.composing.end],
    'selection': [v.selection.baseOffset, v.selection.extentOffset],
  };

  void _add(String id, Map<String, Object?> entry) {
    setState(
      () => _logs[id]!.add({'ms': _clock.elapsedMilliseconds, ...entry}),
    );
  }

  void _reset(String id) {
    setState(() {
      _add(id, {'kind': 'reset'});
      _controllers[id]!.clear();
    });
    _focus[id]!.requestFocus();
  }

  void _click(String id, String button) => _add(id, {
    'kind': 'click',
    'button': button,
    ..._value(_controllers[id]!.value),
  });

  void _save() {
    final json = const JsonEncoder.withIndent('  ').convert({
      'probe': 1,
      'recordedAt': DateTime.now().toUtc().toIso8601String(),
      'userAgent': web.window.navigator.userAgent,
      'platform': web.window.navigator.platform,
      'scenarios': _logs,
    });
    final blob = web.Blob(
      [json.toJS].toJS,
      web.BlobPropertyBag(type: 'application/json'),
    );
    final url = web.URL.createObjectURL(blob);
    final os = web.window.navigator.platform.toLowerCase().startsWith('mac')
        ? 'macos'
        : 'windows';
    web.HTMLAnchorElement()
      ..href = url
      ..download = 'ime-log-$os-chrome.json'
      ..click();
    web.URL.revokeObjectURL(url);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('IME probe · 한글 입력 기록'),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.download),
            label: const Text('저장 (Save)'),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '위에서부터 차례로 하고, 끝나면 오른쪽 위 "저장"을 누릅니다. '
          '두벌식 한글 입력기를 씁니다.',
        ),
        for (final s in scenarios) _scenario(s),
      ],
    ),
  );

  Widget _scenario(Scenario s) {
    final log = _logs[s.id]!;
    final values = log.where((e) => e['kind'] == 'value').length;
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: Theme.of(context).textTheme.titleMedium),
            Text(s.steps),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controllers[s.id],
                    focusNode: _focus[s.id],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (s.withButtons) ...[
                  OutlinedButton(
                    onPressed: () => _click(s.id, 'A'),
                    child: const Text('A (포커스 그대로)'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    focusNode: _buttonFocus,
                    onPressed: () {
                      _buttonFocus.requestFocus();
                      // The focus change commits the composition on most
                      // platforms; log the value after it has arrived.
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _click(s.id, 'B'),
                      );
                    },
                    child: const Text('B (포커스 가져옴)'),
                  ),
                  const SizedBox(width: 8),
                ],
                TextButton(
                  onPressed: () => _reset(s.id),
                  child: const Text('다시'),
                ),
              ],
            ),
            Text(
              '기록: 값 $values개, 전체 ${log.length}개',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
