import 'dart:convert';
import 'package:http/http.dart' as http;

/// Update this once your API is deployed on Render.
/// While testing locally on an Android emulator, use 10.0.2.2 instead of
/// 127.0.0.1 or localhost -- the emulator maps that special address back to
/// your computer's own localhost. On a real physical phone, neither works;
/// you must use the deployed Render URL (or your computer's LAN IP).
class ApiConfig {
  static const String baseUrl = 'http://127.0.0.1:8000';
  // static const String baseUrl = 'https://YOUR-APP-NAME.onrender.com'; // switch to this once deployed
  // static const String baseUrl = 'http://10.0.2.2:8000'; // local Android emulator testing
}

/// Represents the outcome of a prediction request: either a successful
/// numeric result, or a human-readable error message to show the user.
class PredictionResult {
  final double? predictedYield;
  final String? errorMessage;

  const PredictionResult.success(double value)
      : predictedYield = value,
        errorMessage = null;

  const PredictionResult.failure(String message)
      : predictedYield = null,
        errorMessage = message;

  bool get isSuccess => predictedYield != null;
}

class ApiService {
  Future<PredictionResult> predictYield({
    required double plotAreaHa,
    required double cropAreaHa,
    required String cropCategory,
    required String province,
    required String district,
    required String season,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/predict');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'Plot_area_ha': plotAreaHa,
              'Crop_Area_ha': cropAreaHa,
              'CropCategory': cropCategory,
              's1q1': province,
              's1q2': district,
              'Season': season,
              // s1q8 (gender) and s1q9 (age) intentionally omitted -- both
              // were dropped from the trained model after checking feature
              // importance: gender contributed ~0.1% (negligible), and age's
              // effect, while real, was weak enough (correlation ~0.03) that
              // we chose not to ask users for demographic information the
              // model barely uses.
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final value = (data['predicted_yield'] as num).toDouble();
        return PredictionResult.success(value);
      }

      if (response.statusCode == 422) {
        // Pydantic validation error -- pull out the first readable message
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final details = data['detail'];
        String message = 'Some values are out of the expected range.';
        if (details is List && details.isNotEmpty) {
          final first = details.first as Map<String, dynamic>;
          final field = (first['loc'] as List).last;
          message = '$field: ${first['msg']}';
        }
        return PredictionResult.failure(message);
      }

      return PredictionResult.failure(
        'Server error (${response.statusCode}). Please try again.',
      );
    } catch (e) {
      return const PredictionResult.failure(
        'Could not reach the server. Check your internet connection.',
      );
    }
  }
}