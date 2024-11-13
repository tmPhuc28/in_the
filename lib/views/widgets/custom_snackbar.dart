import 'dart:async';
import 'package:flutter/material.dart';

enum SnackbarPosition {
  top,
  bottom,
}

class CustomSnackbar {
  static OverlayEntry? _currentOverlayEntry;
  static Timer? _currentTimer;

  static void _removeCurrentSnackbar() {
    _currentTimer?.cancel();
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;
  }

  static void show({
    required BuildContext context,
    required String message,
    IconData? icon,
    Duration? duration,
    Color? backgroundColor,
    Color? textColor,
    SnackBarAction? action,
    SnackbarPosition position = SnackbarPosition.top,
    VoidCallback? onDismiss,
  }) {
    _removeCurrentSnackbar();

    final overlay = Overlay.of(context);
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);

    final topPadding = mediaQuery.padding.top + 16;
    final bottomPadding = mediaQuery.padding.bottom + 16;

    // Tính toán kích thước tối đa cho snackbar
    final maxHeight = mediaQuery.size.height * 0.4; // 40% chiều cao màn hình

    final animationController = AnimationController(
      vsync: Navigator.of(context),
      duration: const Duration(milliseconds: 300),
    );

    _currentOverlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: position == SnackbarPosition.top ? topPadding : null,
        bottom: position == SnackbarPosition.bottom ? bottomPadding : null,
        left: 16,
        right: 16,
        child: IgnorePointer(
          ignoring: false,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: SlideTransition(
                position: CurvedAnimation(
                  parent: animationController,
                  curve: Curves.easeOut,
                ).drive(Tween<Offset>(
                  begin: Offset(0, position == SnackbarPosition.top ? -1 : 1),
                  end: const Offset(0, 0),
                )),
                child: Dismissible(
                  key: UniqueKey(),
                  direction: position == SnackbarPosition.top
                      ? DismissDirection.up
                      : DismissDirection.down,
                  onDismissed: (_) {
                    _removeCurrentSnackbar();
                    onDismiss?.call();
                  },
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: maxHeight,
                    ),
                    decoration: BoxDecoration(
                      color: backgroundColor ?? Colors.black87,
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (icon != null) ...[
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  icon,
                                  color: textColor ?? Colors.white,
                                  size: 24.0,
                                ),
                              ),
                              const SizedBox(width: 12.0),
                            ],
                            Expanded(
                              child: SingleChildScrollView(
                                child: Text(
                                  message,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textColor ?? Colors.white,
                                    fontSize: 16.0,
                                    height: 1.4,
                                  ),
                                  // Bỏ maxLines và overflow để hiện thị full text
                                ),
                              ),
                            ),
                            if (action != null) ...[
                              const SizedBox(width: 8.0),
                              TextButton(
                                onPressed: () {
                                  _removeCurrentSnackbar();
                                  action.onPressed.call();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  foregroundColor: action.textColor ?? Colors.white,
                                ),
                                child: Text(action.label),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_currentOverlayEntry!);
    animationController.forward();

    _currentTimer = Timer(duration ?? const Duration(seconds: 3), () {
      animationController.reverse().whenComplete(() {
        _removeCurrentSnackbar();
        onDismiss?.call();
      });
    });
  }

  // Các utility methods giữ nguyên...
  static void showSuccess(
      BuildContext context,
      String message, {
        SnackbarPosition position = SnackbarPosition.top,
        Duration? duration,
        VoidCallback? onDismiss,
      }) {
    show(
      context: context,
      message: message,
      icon: Icons.check_circle,
      backgroundColor: Colors.green.shade600,
      duration: duration ?? const Duration(seconds: 2),
      position: position,
      onDismiss: onDismiss,
    );
  }

  static void showError(
      BuildContext context,
      String message, {
        SnackbarPosition position = SnackbarPosition.top,
        Duration? duration,
        VoidCallback? onDismiss,
      }) {
    show(
      context: context,
      message: message,
      icon: Icons.error,
      backgroundColor: Colors.red.shade600,
      duration: duration ?? const Duration(seconds: 3),
      position: position,
      onDismiss: onDismiss,
    );
  }

  static void showWarning(
      BuildContext context,
      String message, {
        SnackbarPosition position = SnackbarPosition.top,
        Duration? duration,
        VoidCallback? onDismiss,
      }) {
    show(
      context: context,
      message: message,
      icon: Icons.warning,
      backgroundColor: Colors.orange.shade700,
      duration: duration ?? const Duration(seconds: 3),
      position: position,
      onDismiss: onDismiss,
    );
  }

  static void showInfo(
      BuildContext context,
      String message, {
        SnackbarPosition position = SnackbarPosition.top,
        Duration? duration,
        VoidCallback? onDismiss,
      }) {
    show(
      context: context,
      message: message,
      icon: Icons.info,
      backgroundColor: Colors.blue.shade600,
      duration: duration ?? const Duration(seconds: 2),
      position: position,
      onDismiss: onDismiss,
    );
  }

  static void dismiss() {
    _removeCurrentSnackbar();
  }
}