import 'dart:io';

import 'package:flutter/material.dart';
import 'package:serious_python/serious_python.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Measuring Python worker stack…')),
      ),
    ),
  );

  try {
    final prefix = 'stack_probe_${DateTime.now().microsecondsSinceEpoch}';
    final launchError = await SeriousPython.run(
      appFileName: 'main.py',
      environmentVariables: {'STACK_PROBE_PREFIX': prefix},
    );
    if (launchError != null) {
      throw StateError('Python launch failed: $launchError');
    }

    // SeriousPython.run() reports worker creation, so wait for Python to
    // finish the NumPy operation. Upstream sets Directory.current to its
    // writable application data directory before starting the worker.
    final stackFile = File('$prefix.stack');
    for (var attempt = 0; attempt < 30; attempt++) {
      if (await stackFile.exists()) {
        final stackBytes = (await stackFile.readAsString()).trim();
        stdout.writeln('STACK_PROBE_STACK_BYTES: $stackBytes');
        await stdout.flush();
        await File('$prefix.ack').writeAsString('continue');
        break;
      }
      if (attempt == 29) {
        throw StateError('Python did not report its stack within 30 seconds');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    final resultFile = File('$prefix.result');
    for (var attempt = 0; attempt < 60; attempt++) {
      if (await resultFile.exists()) {
        final result = (await resultFile.readAsString()).trim();
        stdout.writeln('STACK_PROBE_RESULT: $result');
        await stdout.flush();
        exit(result.contains('numpy=ok') ? 0 : 1);
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    throw StateError('Python did not report a result within 60 seconds');
  } catch (error, stack) {
    stderr.writeln('STACK_PROBE_ERROR: $error\n$stack');
    await stderr.flush();
    exit(1);
  }
}
