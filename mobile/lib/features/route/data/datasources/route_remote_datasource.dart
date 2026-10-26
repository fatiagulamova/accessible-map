// ============================================================
// route_remote_datasource.dart
// Rota ve erişilebilirlik puanını Supabase Edge Function üzerinden getirir.
// ============================================================

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/exceptions.dart';
import '../models/route_model.dart';

/// Rota ve erişilebilirlik verilerini uzak kaynaklardan getirir.
abstract class RouteRemoteDataSource {
  Future<RouteModel> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  });
}

/// `calculate-route-score` Edge Function istemcisi.
class RouteRemoteDataSourceImpl implements RouteRemoteDataSource {
  final SupabaseClient _supabase;

  RouteRemoteDataSourceImpl({required SupabaseClient supabase})
    : _supabase = supabase;

  @override
  Future<RouteModel> getAccessibleRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'calculate-route-score',
        body: {
          'startLat': startLat,
          'startLng': startLng,
          'endLat': endLat,
          'endLng': endLng,
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException(
          message: 'Rota servisi geçersiz bir yanıt döndürdü',
        );
      }

      final payload = Map<String, dynamic>.from(data);
      final routes = payload['routes'];

      if (routes != null && routes is! List) {
        throw const ServerException(
          message: 'Rota servisi geçersiz bir rota listesi döndürdü',
        );
      }

      // Güncel Edge Function `{ routes: [...] }` döndürür. Model, yeni
      // dağıtım tamamlanana kadar eski tek rota yanıtını da kabul eder.
      return RouteModel.fromEdgeFunctionJson(
        payload,
        startLat,
        startLng,
        endLat,
        endLng,
      );
    } on FunctionsFetchException {
      throw const NetworkException(message: 'Rota servisine ulaşılamadı');
    } on FunctionException catch (error) {
      throw ServerException(
        message: _functionErrorMessage(error),
        code: 'EDGE_FUNCTION_${error.status}',
      );
    }
  }

  String _functionErrorMessage(FunctionException error) {
    final details = error.details;

    if (details is Map) {
      final message = details['error'] ?? details['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    return 'Rota servisi ${error.status} yanıtı döndürdü';
  }
}
