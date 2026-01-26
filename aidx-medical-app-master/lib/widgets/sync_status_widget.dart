import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state_service.dart';
import '../services/data_persistence_service.dart';
import '../utils/theme.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';

class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppStateService, DataPersistenceService>(
      builder: (context, appState, dataPersistence, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.13),
                AppTheme.bgGlassMedium.withOpacity(0.18),
                Colors.white.withOpacity(0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: 1.8,
              color: _getStatusColor(appState, dataPersistence).withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor(appState, dataPersistence).withOpacity(0.10),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getStatusColor(appState, dataPersistence),
                          AppTheme.primaryColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getStatusIcon(appState, dataPersistence),
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getStatusTitle(appState, dataPersistence),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getStatusSubtitle(appState, dataPersistence),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (dataPersistence.isSyncing)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatusDetails(appState, dataPersistence),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return AppTheme.infoColor;
    } else if (!appState.isOnline) {
      return AppTheme.warningColor;
    } else if (dataPersistence.offlineQueueSize > 0) {
      return AppTheme.accentColor;
    } else {
      return AppTheme.successColor;
    }
  }

  IconData _getStatusIcon(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return FeatherIcons.refreshCw;
    } else if (!appState.isOnline) {
      return FeatherIcons.wifiOff;
    } else if (dataPersistence.offlineQueueSize > 0) {
      return FeatherIcons.cloudOff;
    } else {
      return FeatherIcons.checkCircle;
    }
  }

  String _getStatusTitle(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return 'Syncing Data';
    } else if (!appState.isOnline) {
      return 'Offline Mode';
    } else if (dataPersistence.offlineQueueSize > 0) {
      return 'Pending Sync';
    } else {
      return 'All Data Synced';
    }
  }

  String _getStatusSubtitle(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return 'Uploading offline data...';
    } else if (!appState.isOnline) {
      return 'Working offline - data will sync when online';
    } else if (dataPersistence.offlineQueueSize > 0) {
      return '${dataPersistence.offlineQueueSize} items waiting to sync';
    } else {
      return 'All data is up to date';
    }
  }

  Widget _buildStatusDetails(AppStateService appState, DataPersistenceService dataPersistence) {
    return Column(
      children: [
        _buildStatusRow('Connectivity', appState.isOnline ? 'Online' : 'Offline', 
            appState.isOnline ? FeatherIcons.wifi : FeatherIcons.wifiOff),
        _buildStatusRow('Cache Size', '${dataPersistence.cacheSize} items', FeatherIcons.database),
        if (dataPersistence.offlineQueueSize > 0)
          _buildStatusRow('Offline Queue', '${dataPersistence.offlineQueueSize} items', FeatherIcons.cloudOff),
        if (dataPersistence.lastSyncTime != null)
          _buildStatusRow('Last Sync', _formatTime(dataPersistence.lastSyncTime!), FeatherIcons.clock),
        if (appState.errors.isNotEmpty)
          _buildStatusRow('Errors', '${appState.errors.length} errors', FeatherIcons.alertTriangle),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              icon,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AppStateService, DataPersistenceService>(
      builder: (context, appState, dataPersistence, child) {
        if (appState.isOnline && dataPersistence.offlineQueueSize == 0 && !dataPersistence.isSyncing) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _getBannerColor(appState, dataPersistence).withOpacity(0.9),
                _getBannerColor(appState, dataPersistence).withOpacity(0.7),
              ],
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getBannerIcon(appState, dataPersistence),
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getBannerMessage(appState, dataPersistence),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (dataPersistence.isSyncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Color _getBannerColor(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return AppTheme.infoColor;
    } else if (!appState.isOnline) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.accentColor;
    }
  }

  IconData _getBannerIcon(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return FeatherIcons.refreshCw;
    } else if (!appState.isOnline) {
      return FeatherIcons.wifiOff;
    } else {
      return FeatherIcons.cloudOff;
    }
  }

  String _getBannerMessage(AppStateService appState, DataPersistenceService dataPersistence) {
    if (dataPersistence.isSyncing) {
      return 'Syncing data...';
    } else if (!appState.isOnline) {
      return 'Working offline';
    } else {
      return '${dataPersistence.offlineQueueSize} items pending sync';
    }
  }
} 