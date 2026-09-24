import 'dart:io';

import 'package:flutter/material.dart';

class MemoryPhoto extends StatelessWidget {
  const MemoryPhoto({super.key, required this.path, this.thumbnail = false});
  final String path;
  final bool thumbnail;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Foto tidak tersedia pada perangkat ini.'),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        ),
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.file(
        File(path),
        width: thumbnail ? 48 : double.infinity,
        height: thumbnail ? 48 : 160,
        cacheWidth: thumbnail ? 144 : 800,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => SizedBox(
          width: thumbnail ? 48 : null,
          height: thumbnail ? 48 : 64,
          child: const Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    ),
  );
}
