import 'package:flutter/material.dart';

import 'project_controller.dart';

/// The key of the row of sound [name] in the Sounds window.
ValueKey<String> soundRowKey(String name) => ValueKey('sounds.$name');

/// The key of the Sounds window's button that adds a sound.
const addSoundKey = ValueKey('sounds.add');

/// File → Sounds (docs/DESIGN.md D138): the open project's sounds, each
/// with its size and a button that takes it out, and a button that adds
/// one. As the Pictures window, without a view of each.
class SoundsDialog extends StatelessWidget {
  const SoundsDialog({super.key, required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    return ListenableBuilder(
      listenable: controller.current,
      builder: (context, _) {
        final sounds = controller.current.sounds;
        return AlertDialog(
          title: Text(s.soundsTitle),
          content: SizedBox(
            width: 480,
            child: sounds.isEmpty
                ? Text(s.noSounds)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final MapEntry(key: name, value: bytes)
                          in sounds.entries)
                        ListTile(
                          key: soundRowKey(name),
                          leading: const Icon(Icons.music_note_outlined),
                          title: Text(name),
                          subtitle: Text(_size(bytes.length)),
                          trailing: IconButton(
                            tooltip: s.removeSound,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                controller.removeSound(context, name),
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              key: addSoundKey,
              onPressed: () => controller.addSound(context),
              child: Text(s.addSound),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.runtime.ok),
            ),
          ],
        );
      },
    );
  }

  static String _size(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).ceil()} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
