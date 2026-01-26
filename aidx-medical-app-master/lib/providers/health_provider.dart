import 'package:flutter/foundation.dart';
import '../models/health_data_model.dart';
import '../repositories/health_repository.dart';

enum HealthDataStatus { initial, loading, loaded, error }

class HealthProvider with ChangeNotifier {
  final HealthRepository _repository = HealthRepository();
  
  // State variables
  HealthDataStatus _status = HealthDataStatus.initial;
  List<HealthDataModel> _healthData = [];
  Map<String, dynamic> _healthSummary = {};
  String? _errorMessage;
  bool _isLoading = false;

  // Getters
  HealthDataStatus get status => _status;
  List<HealthDataModel> get healthData => _healthData;
  Map<String, dynamic> get healthSummary => _healthSummary;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;

  // Get health data by type
  List<HealthDataModel> getHealthDataByType(String type) {
    return _healthData.where((data) => data.type == type).toList();
  }

  // Get latest health data by type
  HealthDataModel? getLatestHealthData(String type) {
    final typeData = getHealthDataByType(type);
    return typeData.isNotEmpty ? typeData.first : null;
  }

  // Load health data stream
  void loadHealthDataStream({String? type, int? limit}) {
    _setStatus(HealthDataStatus.loading);
    
    _repository.getHealthDataStream(type: type, limit: limit).listen(
      (data) {
        _healthData = data;
        _setStatus(HealthDataStatus.loaded);
      },
      onError: (error) {
        _errorMessage = error.toString();
        _setStatus(HealthDataStatus.error);
      },
    );
  }

  // Add health data
  Future<void> addHealthData(HealthDataModel healthData) async {
    try {
      _setLoading(true);
      await _repository.addHealthData(healthData);
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Update health data
  Future<void> updateHealthData(String id, Map<String, dynamic> updates) async {
    try {
      _setLoading(true);
      await _repository.updateHealthData(id, updates);
      
      // Update local data
      final index = _healthData.indexWhere((data) => data.id == id);
      if (index != -1) {
        final updatedData = _healthData[index].copyWith(
          value: updates['value'] ?? _healthData[index].value,
          notes: updates['notes'] ?? _healthData[index].notes,
          metadata: updates['metadata'] ?? _healthData[index].metadata,
        );
        _healthData[index] = updatedData;
        notifyListeners();
      }
      
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Delete health data
  Future<void> deleteHealthData(String id) async {
    try {
      _setLoading(true);
      await _repository.deleteHealthData(id);
      
      // Remove from local data
      _healthData.removeWhere((data) => data.id == id);
      notifyListeners();
      
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Load health summary
  Future<void> loadHealthSummary() async {
    try {
      _setLoading(true);
      _healthSummary = await _repository.getHealthSummary();
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Load health data for date range
  Future<void> loadHealthDataForDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? type,
  }) async {
    try {
      _setLoading(true);
      _healthData = await _repository.getHealthDataForDateRange(
        startDate,
        endDate,
        type: type,
      );
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Get latest health data by type
  Future<HealthDataModel?> loadLatestHealthData(String type) async {
    try {
      _setLoading(true);
      final latestData = await _repository.getLatestHealthData(type);
      _setLoading(false);
      return latestData;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  // Batch add health data
  Future<void> addHealthDataBatch(List<HealthDataModel> healthDataList) async {
    try {
      _setLoading(true);
      await _repository.addHealthDataBatch(healthDataList);
      _setLoading(false);
    } catch (e) {
      _setLoading(false);
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Clear error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Reset state
  void reset() {
    _status = HealthDataStatus.initial;
    _healthData = [];
    _healthSummary = {};
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  // Helper methods
  void _setStatus(HealthDataStatus status) {
    _status = status;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Get health data statistics
  Map<String, dynamic> getHealthDataStats(String type) {
    final typeData = getHealthDataByType(type);
    if (typeData.isEmpty) return {};

    final numericValues = typeData
        .where((data) => data.value is num)
        .map((data) => data.value as num)
        .toList();

    if (numericValues.isEmpty) return {};

    return {
      'count': typeData.length,
      'latest': typeData.first.value,
      'average': numericValues.reduce((a, b) => a + b) / numericValues.length,
      'min': numericValues.reduce((a, b) => a < b ? a : b),
      'max': numericValues.reduce((a, b) => a > b ? a : b),
      'lastUpdated': typeData.first.timestamp,
    };
  }

  // Check if data is stale (older than 24 hours)
  bool isDataStale() {
    if (_healthData.isEmpty) return true;
    
    final latestData = _healthData.first;
    final twentyFourHoursAgo = DateTime.now().subtract(const Duration(hours: 24));
    
    return latestData.timestamp.isBefore(twentyFourHoursAgo);
  }
} 