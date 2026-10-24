import 'package:flutter/material.dart';

import 'project_controller.dart';

/// The key of the row of picture [name] in the Pictures window.
ValueKey<String> pictureRowKey(String name) => ValueKey('pictures.$name');

/// The key of the Pictures window's button that adds a picture.
const addPictureKey = ValueKey('pictures.add');

/// File → Pictures (D51): the open project's pictures, each with a small
/// view of it and a button that takes it out, and a button that adds one.
class PicturesDialog extends StatelessWidget {
  const PicturesDialog({super.key, required this.controller});

  final ProjectController controller;

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    return ListenableBuilder(
      listenable: controller.current,
      builder: (context, _) {
        final pictures = controller.current.pictures;
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(s.picturesTitle),
          content: SizedBox(
            width: 480,
            child: pictures.isEmpty
                ? Text(s.noPictures)
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final MapEntry(key: name, value: bytes)
                          in pictures.entries)
                        ListTile(
                          key: pictureRowKey(name),
                          leading: SizedBox.square(
                            dimension: 40,
                            child: Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (context, _, _) => Icon(
                                Icons.broken_image_outlined,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ),
                          title: Text(name),
                          subtitle: Text(_size(bytes.length)),
                          trailing: IconButton(
                            tooltip: s.removePicture,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                controller.removePicture(context, name),
                          ),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              key: addPictureKey,
              onPressed: () => controller.addPicture(context),
              child: Text(s.addPicture),
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
