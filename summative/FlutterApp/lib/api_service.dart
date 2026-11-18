// Calls the deployed FastAPI /predict endpoint and turns every failure
// into a message the user can read.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'input_fields.dart';

const String apiBaseUrl = 'https://internet-access-predictor.onrender.com';

/// Render's free tier sleeps, so the first request can take up to a minute.
const Duration requestTimeout = Duration(seconds: 90);

class PredictionResult {
  final double percent;
  final String? interpretation;

  const PredictionResult(this.percent, this.interpretation);
}

/// Error with a message that is safe to show in the result area.
class PredictionException implements Exception {
  final String message;
  const PredictionException(this.message);
}

/// Step 1: check the text fields and build the JSON body.
/// Catches empty fields and wrong types before anything is sent.
/// Range checks are done by the API (Pydantic), which answers with 422.
Map<String, dynamic> buildRequestBody(Map<String, String> values) {
  final body = <String, dynamic>{};
  final problems = <String>[];

  for (final spec in inputs) {
    final text = (values[spec.key] ?? '').trim();
    if (text.isEmpty) {
      problems.add('${spec.label} is required.');
      continue;
    }
    switch (spec.kind) {
      case InputKind.integer:
        final v = int.tryParse(text);
        if (v == null) {
          problems.add(
            '${spec.label} must be a whole number (e.g. ${spec.hint}).',
          );
        } else {
          body[spec.key] = v;
        }
      case InputKind.decimal:
        final v = double.tryParse(text.replaceAll(',', ''));
        if (v == null) {
          problems.add('${spec.label} must be a number (e.g. ${spec.hint}).');
        } else {
          body[spec.key] = v;
        }
      case InputKind.text:
        body[spec.key] = text;
    }
  }

  if (problems.isNotEmpty) throw PredictionException(problems.join('\n'));
  return body;
}

/// Step 2: POST the body to /predict and read the answer.
Future<PredictionResult> fetchPrediction(Map<String, dynamic> body) async {
  final http.Response response;
  try {
    response = await http
        .post(
          Uri.parse('$apiBaseUrl/predict'),
          headers: const {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
  } on TimeoutException {
    throw const PredictionException(
      'The server took too long to answer. It may be waking up; '
      'please press Predict again.',
    );
  } catch (_) {
    throw const PredictionException(
      'Could not reach the API. Check your internet connection and try again.',
    );
  }

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return PredictionResult(
      (data['predicted_internet_users_percent'] as num).toDouble(),
      data['interpretation'] as String?,
    );
  }
  if (response.statusCode == 422) {
    // Pydantic validation error, e.g. a value out of range.
    throw PredictionException(_readValidationError(response.body));
  }
  throw PredictionException(
    'Server error (${response.statusCode}). Please try again.',
  );
}

/// Turns FastAPI's 422 "detail" list into lines like
/// "Access to electricity (%): Input should be less than or equal to 100".
String _readValidationError(String responseBody) {
  try {
    final detail = jsonDecode(responseBody)['detail'];
    if (detail is List) {
      return detail
          .map((e) {
            final field = (e['loc'] as List).last.toString();
            final label = specByKey[field]?.label ?? field;
            return '$label: ${e['msg']}';
          })
          .join('\n');
    }
    return detail.toString();
  } catch (_) {
    return 'The server rejected the input.';
  }
}
