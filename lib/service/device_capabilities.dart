import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Rendering choices derived from capabilities, not from a single RAM cutoff.
enum RenderingTier { full, compatible, conservative }

@immutable
class DeviceCapabilities {
  const DeviceCapabilities({
    required this.isAndroid,
    required this.sdkInt,
    required this.memoryClassMb,
    required this.isLowRamDevice,
    required this.supports64Bit,
    required this.openGlEsMajor,
  });

  /// A safe default while capability discovery is unavailable (web, desktop,
  /// tests, or a platform-channel failure).
  const DeviceCapabilities.standard()
    : isAndroid = false,
      sdkInt = 0,
      memoryClassMb = 0,
      isLowRamDevice = false,
      supports64Bit = true,
      openGlEsMajor = 3;

  final bool isAndroid;
  final int sdkInt;
  final int memoryClassMb;
  final bool isLowRamDevice;
  final bool supports64Bit;
  final int openGlEsMajor;

  factory DeviceCapabilities.fromPlatformMap(Map<Object?, Object?> values) {
    int integer(String key) => (values[key] as num?)?.toInt() ?? 0;
    bool boolean(String key) => values[key] == true;
    return DeviceCapabilities(
      isAndroid: boolean('isAndroid'),
      sdkInt: integer('sdkInt'),
      memoryClassMb: integer('memoryClassMb'),
      isLowRamDevice: boolean('isLowRamDevice'),
      supports64Bit: boolean('supports64Bit'),
      openGlEsMajor: integer('openGlEsMajor'),
    );
  }

  RenderingTier get renderingTier {
    if (!isAndroid) return RenderingTier.full;
    final legacyAndroid = sdkInt > 0 && sdkInt <= 25;
    final limitedGraphics = openGlEsMajor > 0 && openGlEsMajor < 3;
    final limitedProcess = !supports64Bit;
    final entryClassMemory =
        isLowRamDevice || (memoryClassMb > 0 && memoryClassMb <= 128);

    // Old Android plus either a 32-bit process or ES 2 graphics has proven to
    // be the riskiest combination for off-screen raster effects. RAM alone is
    // intentionally insufficient to enter this tier.
    if (legacyAndroid && (limitedProcess || limitedGraphics)) {
      return RenderingTier.conservative;
    }
    if (legacyAndroid || limitedGraphics || entryClassMemory) {
      return RenderingTier.compatible;
    }
    return RenderingTier.full;
  }

  bool get useBasicEffects => renderingTier == RenderingTier.conservative;
  bool get reduceEffects => renderingTier != RenderingTier.full;
}

class DeviceCapabilityService {
  static const _channel = MethodChannel('loanx');

  static Future<DeviceCapabilities> load() async {
    if (kIsWeb) return const DeviceCapabilities.standard();
    try {
      final values = await _channel.invokeMapMethod<Object?, Object?>(
        'deviceCapabilities',
      );
      return values == null
          ? const DeviceCapabilities.standard()
          : DeviceCapabilities.fromPlatformMap(values);
    } on PlatformException {
      return const DeviceCapabilities.standard();
    }
  }
}

/// Makes the profile available below [MaterialApp.builder] without coupling UI
/// widgets to a state-management package.
class DeviceCapabilitiesScope extends InheritedWidget {
  const DeviceCapabilitiesScope({
    required this.capabilities,
    required super.child,
    super.key,
  });

  final DeviceCapabilities capabilities;

  static DeviceCapabilities of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DeviceCapabilitiesScope>()
          ?.capabilities ??
      const DeviceCapabilities.standard();

  @override
  bool updateShouldNotify(DeviceCapabilitiesScope oldWidget) =>
      capabilities != oldWidget.capabilities;
}
