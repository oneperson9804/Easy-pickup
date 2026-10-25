import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PageCaptureState {
  const PageCaptureState({
    this.enabled = false,
    this.connected = false,
    this.consented = false,
    this.running = false,
    this.screenshotSupported = false,
    this.selectedPackages = const {},
    this.platforms = const {},
  });

  factory PageCaptureState.fromMap(Map<String, dynamic> map) =>
      PageCaptureState(
        enabled: map['enabled'] == true,
        connected: map['connected'] == true,
        consented: map['consented'] == true,
        running: map['running'] == true,
        screenshotSupported: map['screenshotSupported'] == true,
        selectedPackages: (map['selectedPackages'] as List? ?? [])
            .whereType<String>()
            .toSet(),
        platforms: Map<String, String>.from(map['platforms'] as Map? ?? {}),
      );

  final bool enabled, connected, consented, running, screenshotSupported;
  final Set<String> selectedPackages;
  final Map<String, String> platforms;
}

class PageCaptureService {
  static const channel = MethodChannel('easy_pickup/page_capture');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<PageCaptureState> state() async => PageCaptureState.fromMap(
    await channel.invokeMapMethod<String, dynamic>('state') ?? {},
  );

  Future<PageCaptureState> configure({
    required bool consented,
    required Set<String> selectedPackages,
  }) async => PageCaptureState.fromMap(
    await channel.invokeMapMethod<String, dynamic>('configure', {
          'consented': consented,
          'selectedPackages': selectedPackages.toList(),
        }) ??
        {},
  );

  Future<void> openSettings() => channel.invokeMethod<void>('openSettings');
  Future<PageCaptureState> startSession() async => PageCaptureState.fromMap(
    await channel.invokeMapMethod<String, dynamic>('startSession') ?? {},
  );
  Future<PageCaptureState> stopSession() async => PageCaptureState.fromMap(
    await channel.invokeMapMethod<String, dynamic>('stopSession') ?? {},
  );
}
