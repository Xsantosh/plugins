// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

import 'package:e2e/common.dart' as e2e;
import 'package:path/path.dart' as path;

/// This method remains for backword compatibility.
Future<void> main() => e2eDriver();

/// Flutter Driver test output directory.
///
/// Tests should write any output files to this directory. Defaults to the path
/// set in the FLUTTER_TEST_OUTPUTS_DIR environment variable, or `build` if
/// unset.
String testOutputsDirectory =
    Platform.environment['FLUTTER_TEST_OUTPUTS_DIR'] ?? 'build';

/// The callback type to handle [e2e.Response.data] after the test succcess.
typedef ResponseDataCallback = FutureOr<void> Function(Map<String, dynamic>);

/// Writes a json-serializable json data to to
/// [testOutputsDirectory]/`testOutputFilename.json`.
///
/// This is the default `responseDataCallback` in [e2eDriver].
Future<void> writeResponseData(
  Map<String, dynamic> data, {
  String testOutputFilename = 'e2e_response_data',
  String destinationDirectory,
}) async {
  assert(testOutputFilename != null);
  destinationDirectory ??= testOutputsDirectory;
  await fs.directory(destinationDirectory).create(recursive: true);
  final File file = fs.file(path.join(
    destinationDirectory,
    '$testOutputFilename.json',
  ));
  final String resultString = _encodeJson(data, true);
  await file.writeAsString(resultString);
}

/// Adaptor to run E2E test using `flutter drive`.
///
/// `timeout` controls the longest time waited before the test ends.
/// It is not necessarily the execution time for the test app: the test may
/// finish sooner than the `timeout`.
///
/// `responseDataCallback` is the handler for processing [e2e.Response.data].
/// The default value is `writeResponseData`.
///
/// To an E2E test `<test_name>.dart` using `flutter drive`, put a file named
/// `<test_name>_test.dart` in the app's `test_driver` directory:
///
/// ```dart
/// import 'dart:async';
///
/// import 'package:e2e/e2e_driver.dart' as e2e;
///
/// Future<void> main() async => e2e.e2eDriver();
///
/// ```
Future<void> e2eDriver({
  Duration timeout = const Duration(minutes: 1),
  ResponseDataCallback responseDataCallback = writeResponseData,
}) async {
  final FlutterDriver driver = await FlutterDriver.connect();
  final String jsonResult = await driver.requestData(null, timeout: timeout);
  final e2e.Response response = e2e.Response.fromJson(jsonResult);
  await driver.close();

  if (response.allTestsPassed) {
    print('All tests passed.');
    if (responseDataCallback != null) {
      await responseDataCallback(response.data);
    }
    exit(0);
  } else {
    print('Failure Details:\n${response.formattedFailureDetails}');
    exit(1);
  }
}

const JsonEncoder _prettyEncoder = JsonEncoder.withIndent('  ');

String _encodeJson(Map<String, dynamic> jsonObject, bool pretty) {
  return pretty ? _prettyEncoder.convert(jsonObject) : json.encode(jsonObject);
}
