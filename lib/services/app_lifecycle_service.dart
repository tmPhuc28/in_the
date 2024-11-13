import 'package:flutter/widgets.dart';

class AppLifecycleService extends ChangeNotifier with WidgetsBindingObserver {
  bool _isPreviewOpen = false;
  bool _isResumed = false;

  VoidCallback? onResume;
  VoidCallback? onPause;
  VoidCallback? onDetach;
  VoidCallback? onInactive;

  AppLifecycleService() {
    debugPrint('Initializing AppLifecycleService');
    WidgetsBinding.instance.addObserver(this);
    // Kiểm tra state ban đầu
    _isResumed = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  void setPreviewState(bool isOpen) {
    debugPrint('Preview state changed: $isOpen');
    _isPreviewOpen = isOpen;
    notifyListeners();
  }

  bool get isPreviewOpen => _isPreviewOpen;
  bool get isResumed => _isResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('Lifecycle state changed to: $state');

    switch (state) {
      case AppLifecycleState.resumed:
        _isResumed = true;
        debugPrint('App resumed - calling onResume callback');
        onResume?.call();
        notifyListeners();

      case AppLifecycleState.paused:
        _isResumed = false;
        debugPrint('App paused - calling onPause callback');
        onPause?.call();
        notifyListeners();

      case AppLifecycleState.detached:
        _isResumed = false;
        debugPrint('App detached - calling onDetach callback');
        onDetach?.call();
        notifyListeners();

      case AppLifecycleState.inactive:
        debugPrint('App inactive - calling onInactive callback');
        onInactive?.call();
        notifyListeners();

      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    debugPrint('Disposing AppLifecycleService');
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}