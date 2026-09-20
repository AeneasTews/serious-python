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
    final resultName =
        'stack_probe_${DateTime.now().microsecondsSinceEpoch}.result';
    final launchError = await SeriousPython.run(
      appFileName: 'main.py',
      environmentVariables: {'STACK_PROBE_RESULT': resultName},
    );
    if (launchError != null) {
      throw StateError('Python launch failed: $launchError');
    }

    // SeriousPython.run() reports worker creation, so wait for Python to
    // finish the NumPy operation. Upstream sets Directory.current to its
    // writable application data directory before starting the worker.
    final resultFile = File(resultName);
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
