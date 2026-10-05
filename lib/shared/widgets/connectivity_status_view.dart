import 'dart:async';

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
    this.showOfflineBanner = true,
    super.key,
  });

  final ConnectivityService connectivityService;
  final Widget child;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;
  final bool showOfflineBanner;

  @override
  State<ConnectivityStatusView> createState() => _ConnectivityStatusViewState();
}

class _ConnectivityStatusViewState extends State<ConnectivityStatusView> {
  ConnectivityStatus? _lastDefinitiveStatus;
  bool _showOfflineBanner = false;
  bool _showRecoveryBanner = false;
  Timer? _recoveryTimer;

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
    _recoveryTimer?.cancel();
    _showRecoveryBanner = false;
    _showOfflineBanner = false;
    _applyStatus(widget.connectivityService.status, notifyRecovery: false);
  }

  @override
  void dispose() {
    _recoveryTimer?.cancel();
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
        _recoveryTimer?.cancel();
        if (_showRecoveryBanner) {
          setState(() => _showRecoveryBanner = false);
        }
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
              _showRecoveryNotice();
            }
          });
        }
    }
  }

  void _showRecoveryNotice() {
    if (!widget.connectivityService.isOnline) return;
    _recoveryTimer?.cancel();
    setState(() => _showRecoveryBanner = true);
    _recoveryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showRecoveryBanner = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: AnimatedSwitcher(
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
              child: _showOfflineBanner && widget.showOfflineBanner
                  ? const _OfflineConnectivityBanner(
                      key: ValueKey<String>('offline_connectivity_banner'),
                    )
                  : _showRecoveryBanner
                  ? const _OfflineConnectivityBanner(
                      key: ValueKey<String>('recovery_connectivity_banner'),
                      recovered: true,
                    )
                  : const SizedBox.shrink(
                      key: ValueKey<String>('offline_connectivity_empty'),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineConnectivityBanner extends StatelessWidget {
  const _OfflineConnectivityBanner({this.recovered = false, super.key});

  final bool recovered;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      bottom: false,
      minimum: const EdgeInsets.all(AppSpacing.screen),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizing.maxContentWidth,
          ),
          child: Material(
            color: colors.surfaceStrong,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
              side: BorderSide(
                color: recovered ? colors.success : colors.error,
              ),
            ),
            child: Container(
              width: double.infinity,
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
                      Icon(
                        recovered
                            ? Icons.check_circle_outline
                            : Icons.wifi_off_outlined,
                        color: recovered ? colors.success : colors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              recovered
                                  ? AppStrings.connectionRestored
                                  : AppStrings.offlineBannerTitle,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!recovered) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                AppStrings.offlineBannerBody,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
