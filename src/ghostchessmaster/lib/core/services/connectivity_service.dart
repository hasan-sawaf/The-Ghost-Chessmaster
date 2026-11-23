import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../features/history/data/match_history_service.dart';
import '../../features/training/data/training_campaign_service.dart';
import '../../main.dart';
import '../widgets/app_snack_bar.dart';

/// Core service monitoring device Internet connectivity and triggering automatic sync & user feedback.
class InternetConnectivityService {
  static final InternetConnectivityService _instance = InternetConnectivityService._internal();
  static InternetConnectivityService get instance => _instance;
  InternetConnectivityService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _timer;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  bool _hasInitialCheckRun = false;

  void initialize() {
    _checkConnection();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkConnection());
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  Future<void> _checkConnection() async {
    bool currentOnline = false;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 2));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        currentOnline = true;
      }
    } catch (_) {
      currentOnline = false;
    }

    if (!_hasInitialCheckRun) {
      _hasInitialCheckRun = true;
      _isOnline = currentOnline;
      _controller.add(_isOnline);
      if (_isOnline) {
        MatchHistoryService.instance.syncCachedMatchesToFirebase();
        TrainingCampaignService.instance.syncCampaignToFirebase();
      }
      return;
    }

    if (_isOnline != currentOnline) {
      _isOnline = currentOnline;
      _controller.add(_isOnline);

      final navContext = appNavigatorKey.currentContext;
      if (_isOnline) {
        debugPrint('[CONNECTIVITY] Internet connection restored.');
        if (navContext != null && navContext.mounted) {
          AppSnackBar.showSuccess(
            navContext,
            'Internet connection restored / تم استعادة الاتصال بالإنترنت 🌐',
            iconAsset: 'assets/icons/1024x/correct_1024x.png',
          );
        }
        // Auto sync all cached offline matches & campaign progress to Firebase Firestore
        MatchHistoryService.instance.syncCachedMatchesToFirebase();
        TrainingCampaignService.instance.syncCampaignToFirebase();
      } else {
        debugPrint('[CONNECTIVITY] No internet connection.');
        if (navContext != null && navContext.mounted) {
          AppSnackBar.showWarning(
            navContext,
            'No internet connection / لا يوجد اتصال بالإنترنت 📡',
            iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
          );
        }
      }
    }
  }
}
