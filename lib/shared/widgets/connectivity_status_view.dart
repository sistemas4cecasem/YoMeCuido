import 'package:flutter/material.dart';

import '../../app/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../services/connectivity_service.dart';

class ConnectivityStatusView extends StatefulWidget {
  const ConnectivityStatusView({
    required this.connectivityService,
    required this.child,
    this.scaffoldMessengerKey,
    super.key,
  });

  final ConnectivityService connectivityService;
  final Widget child;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  State<ConnectivityStatusView> createState() => _ConnectivityStatusViewState();
}

class _ConnectivityStatusViewState extends State<ConnectivityStatusView> {
  ConnectivityStatus? _lastDefinitiveStatus;
  bool _showOfflineBanner = false;

  @override
  void initState() {
    super.initState();
    widget.connectivityService.addListener(_handleConnectivityChanged);
    _setInitialStatus(widget.connectivityService.status);
  }

  @override
  void didUpdateWidget(covariant ConnectivityStatusView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connectivityService == widget.connectivityService) {
      return;
    }
    oldWidget.connectivityService.removeListener(_handleConnectivityChanged);
    widget.connectivityService.addListener(_handleConnectivityChanged);
    _lastDefinitiveStatus = null;
    _showOfflineBanner = false;
    _applyStatus(widget.connectivityService.status, notifyRecovery: false);
  }

  @override
  void dispose() {
    widget.connectivityService.removeListener(_handleConnectivityChanged);
    super.dispose();
  }

  void _handleConnectivityChanged() {
    _applyStatus(widget.connectivityService.status);
  }

  void _setInitialStatus(ConnectivityStatus status) {
    switch (status) {
      case ConnectivityStatus.checking:
        break;
      case ConnectivityStatus.offline:
        _lastDefinitiveStatus = ConnectivityStatus.offline;
        _showOfflineBanner = true;
      case ConnectivityStatus.online:
        _lastDefinitiveStatus = ConnectivityStatus.online;
    }
  }

  void _applyStatus(ConnectivityStatus status, {bool notifyRecovery = true}) {
    switch (status) {
      case ConnectivityStatus.checking:
        if (_lastDefinitiveStatus != ConnectivityStatus.offline &&
            _showOfflineBanner) {
          setState(() {
            _showOfflineBanner = false;
          });
        }
      case ConnectivityStatus.offline:
        _lastDefinitiveStatus = ConnectivityStatus.offline;
        if (!_showOfflineBanner) {
          setState(() {
            _showOfflineBanner = true;
          });
        }
      case ConnectivityStatus.online:
        final shouldNotifyRecovery =
            notifyRecovery &&
            _lastDefinitiveStatus == ConnectivityStatus.offline;
        _lastDefinitiveStatus = ConnectivityStatus.online;
        if (_showOfflineBanner) {
          setState(() {
            _showOfflineBanner = false;
          });
        }
        if (shouldNotifyRecovery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showRecoverySnackBar();
            }
          });
        }
    }
  }

  void _showRecoverySnackBar() {
    final colors = context.colors;
    final messenger =
        widget.scaffoldMessengerKey?.currentState ??
        ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          backgroundColor: colors.surfaceStrong,
          margin: const EdgeInsets.all(AppSpacing.screen),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
            side: BorderSide(color: colors.success),
          ),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: colors.success),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  AppStrings.connectionRestored,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSwitcher(
          duration: duration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1,
              child: child,
            );
          },
          child: _showOfflineBanner
              ? const _OfflineConnectivityBanner(
                  key: ValueKey<String>('offline_connectivity_banner'),
                )
              : const SizedBox.shrink(
                  key: ValueKey<String>('offline_connectivity_empty'),
                ),
        ),
      ],
    );
  }
}

class _OfflineConnectivityBanner extends StatelessWidget {
  const _OfflineConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      top: false,
      child: Material(
        color: colors.surfaceStrong,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surfaceStrong,
            border: Border(top: BorderSide(color: colors.error)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screen,
            vertical: AppSpacing.sm,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizing.maxContentWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.wifi_off_outlined, color: colors.error),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AppStrings.offlineBannerTitle,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          AppStrings.offlineBannerBody,
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
