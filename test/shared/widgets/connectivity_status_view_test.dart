import 'dart:async';

import 'package:demo_yomecuido/app/app_strings.dart';
import 'package:demo_yomecuido/core/theme/app_theme.dart';
import 'package:demo_yomecuido/shared/services/connectivity_service.dart';
import 'package:demo_yomecuido/shared/widgets/connectivity_status_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('checking does not show the offline indicator', (tester) async {
    final service = ConnectivityService(
      networkMonitor: _FakeNetworkInterfaceMonitor(),
      backendProbe: _FakeBackendConnectivityProbe(),
    );
    addTearDown(service.dispose);

    await _pumpStatusView(tester, service);

    expect(find.text(AppStrings.offlineBannerTitle), findsNothing);
    expect(find.text(AppStrings.connectionRestored), findsNothing);
  });

  testWidgets('initial online does not show persistent or recovery UI', (
    tester,
  ) async {
    final service = ConnectivityService(
      networkMonitor: _FakeNetworkInterfaceMonitor(),
      backendProbe: _FakeBackendConnectivityProbe()..backendReachable = true,
    );
    addTearDown(service.dispose);

    await service.checkConnection();
    await _pumpStatusView(tester, service);

    expect(find.text(AppStrings.offlineBannerTitle), findsNothing);
    expect(find.text(AppStrings.connectionRestored), findsNothing);
  });

  testWidgets('offline shows a persistent global indicator', (tester) async {
    final service = ConnectivityService(
      networkMonitor: _FakeNetworkInterfaceMonitor(hasInterface: false),
      backendProbe: _FakeBackendConnectivityProbe(),
    );
    addTearDown(service.dispose);

    await service.checkConnection();
    await _pumpStatusView(tester, service);

    expect(find.text(AppStrings.offlineBannerTitle), findsOneWidget);
    expect(find.text(AppStrings.offlineBannerBody), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
  });

  testWidgets('offline to online hides banner and shows recovery feedback', (
    tester,
  ) async {
    final network = _FakeNetworkInterfaceMonitor(hasInterface: false);
    final backend = _FakeBackendConnectivityProbe();
    final service = ConnectivityService(
      networkMonitor: network,
      backendProbe: backend,
    );
    addTearDown(service.dispose);

    await service.checkConnection();
    await _pumpStatusView(tester, service);
    expect(find.text(AppStrings.offlineBannerTitle), findsOneWidget);

    network.hasInterface = true;
    backend.backendReachable = true;
    await service.checkConnection();
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.offlineBannerTitle), findsNothing);
    expect(find.text(AppStrings.connectionRestored), findsOneWidget);
  });

  testWidgets('rebuild does not show a false recovery notification', (
    tester,
  ) async {
    final service = ConnectivityService(
      networkMonitor: _FakeNetworkInterfaceMonitor(),
      backendProbe: _FakeBackendConnectivityProbe()..backendReachable = true,
    );
    addTearDown(service.dispose);

    await service.checkConnection();
    await _pumpStatusView(tester, service);
    await _pumpStatusView(tester, service, marker: 'Contenido actualizado');

    expect(find.text('Contenido actualizado'), findsOneWidget);
    expect(find.text(AppStrings.connectionRestored), findsNothing);
  });

  testWidgets('repeated offline checks keep a single visual indicator', (
    tester,
  ) async {
    final service = ConnectivityService(
      networkMonitor: _FakeNetworkInterfaceMonitor(hasInterface: false),
      backendProbe: _FakeBackendConnectivityProbe(),
    );
    addTearDown(service.dispose);

    await service.checkConnection();
    await _pumpStatusView(tester, service);
    await service.checkConnection();
    await tester.pump();

    expect(find.text(AppStrings.offlineBannerTitle), findsOneWidget);
    expect(find.text(AppStrings.connectionRestored), findsNothing);
  });
}

Future<void> _pumpStatusView(
  WidgetTester tester,
  ConnectivityService service, {
  String marker = 'Contenido',
}) async {
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  await tester.pumpWidget(
    MaterialApp(
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.data(),
      home: ConnectivityStatusView(
        connectivityService: service,
        scaffoldMessengerKey: messengerKey,
        child: Scaffold(body: Center(child: Text(marker))),
      ),
    ),
  );
  await tester.pump();
}

class _FakeNetworkInterfaceMonitor implements NetworkInterfaceMonitor {
  _FakeNetworkInterfaceMonitor({this.hasInterface = true});

  final _controller = StreamController<bool>.broadcast();
  bool hasInterface;

  @override
  Future<bool> hasNetworkInterface() async => hasInterface;

  @override
  Stream<bool> get onNetworkInterfaceChanged => _controller.stream;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeBackendConnectivityProbe implements BackendConnectivityProbe {
  bool backendReachable = false;

  @override
  Future<bool> canReachBackend({required Duration timeout}) async {
    return backendReachable;
  }
}
