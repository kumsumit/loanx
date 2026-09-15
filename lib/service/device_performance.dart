import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Overall device capability.
///
/// This is intentionally broader than "high-end / low-end".
/// It describes how aggressively the UI can use expensive visual features.
enum PerformanceTier { ultra, high, standard, safe }

/// Centralized device-performance configuration for LoanX.
///
/// Responsibilities:
/// - Read native Android device capabilities.
/// - Classify the device.
/// - Expose safe UI-performance decisions.
/// - Prevent individual screens from implementing their own
///   inconsistent device checks.
///
/// Usage:
///
/// ```dart
/// await DevicePerformance.initialize();
///
/// if (DevicePerformance.enableHeavyAnimations) {
///   // Rich animation.
/// } else {
///   // Lightweight animation.
/// }
/// ```
class DevicePerformance {
  DevicePerformance._();

  static const MethodChannel _channel = MethodChannel('loanx');

  static bool _initialized = false;

  static Map<String, dynamic> _capabilities = <String, dynamic>{};

  static PerformanceTier _tier = PerformanceTier.standard;

  /// Whether native capabilities have been loaded.
  static bool get initialized => _initialized;

  /// Raw native capabilities.
  ///
  /// This is useful for diagnostics/telemetry.
  static Map<String, dynamic> get capabilities =>
      Map<String, dynamic>.unmodifiable(_capabilities);

  /// Current performance tier.
  static PerformanceTier get tier => _tier;

  // ---------------------------------------------------------------------------
  // INITIALIZATION
  // ---------------------------------------------------------------------------

  /// Loads device capabilities from Android.
  ///
  /// This should normally be called once during application startup,
  /// before the first expensive UI is built.
  static Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      final result = await _channel.invokeMethod<dynamic>('deviceCapabilities');

      if (result is Map) {
        _capabilities = Map<String, dynamic>.from(result);
      } else {
        _capabilities = <String, dynamic>{};
      }

      _tier = _parseTier(_capabilities['performanceTier']);
    } catch (error, stackTrace) {
      /*
       * Performance adaptation must NEVER prevent LoanX from starting.
       *
       * If native capability detection fails, use the conservative
       * STANDARD profile.
       */
      debugPrint('DevicePerformance initialization failed: $error');

      debugPrintStack(stackTrace: stackTrace);

      _capabilities = <String, dynamic>{};
      _tier = PerformanceTier.standard;
    }

    _initialized = true;
  }

  /// Re-reads native capabilities.
  ///
  /// Normally unnecessary, but useful for diagnostics or future adaptive
  /// logic.
  static Future<void> refresh() async {
    _initialized = false;
    await initialize();
  }

  // ---------------------------------------------------------------------------
  // BASIC DEVICE INFORMATION
  // ---------------------------------------------------------------------------

  static int get sdkInt => _intValue(_capabilities['sdkInt']) ?? 0;

  static String get androidRelease =>
      _stringValue(_capabilities['androidRelease']) ?? '';

  static String get manufacturer =>
      _stringValue(_capabilities['manufacturer']) ?? '';

  static String get brand => _stringValue(_capabilities['brand']) ?? '';

  static String get model => _stringValue(_capabilities['model']) ?? '';

  static String get device => _stringValue(_capabilities['device']) ?? '';

  static String get product => _stringValue(_capabilities['product']) ?? '';

  static String get board => _stringValue(_capabilities['board']) ?? '';

  // ---------------------------------------------------------------------------
  // CPU
  // ---------------------------------------------------------------------------

  static int get cpuCores => _intValue(_capabilities['cpuCores']) ?? 1;

  // ---------------------------------------------------------------------------
  // MEMORY
  // ---------------------------------------------------------------------------

  static int get memoryClassMb =>
      _intValue(_capabilities['memoryClassMb']) ?? 128;

  static bool get isLowRamDevice => _boolValue(_capabilities['isLowRamDevice']);

  // ---------------------------------------------------------------------------
  // ABI
  // ---------------------------------------------------------------------------

  static bool get supports64Bit => _boolValue(_capabilities['supports64Bit']);

  static List<String> get supportedAbis =>
      _stringList(_capabilities['supportedAbis']);

  static List<String> get supported32BitAbis =>
      _stringList(_capabilities['supported32BitAbis']);

  static List<String> get supported64BitAbis =>
      _stringList(_capabilities['supported64BitAbis']);

  // ---------------------------------------------------------------------------
  // GPU / GRAPHICS
  // ---------------------------------------------------------------------------

  static String get openGlEsVersion =>
      _stringValue(_capabilities['openGlEsVersion']) ?? '';

  static int get openGlEsMajor =>
      _intValue(_capabilities['openGlEsMajor']) ?? 0;

  static bool get supportsVulkan => _boolValue(_capabilities['supportsVulkan']);

  static bool get hardwareAccelerationEnabled =>
      _boolValue(_capabilities['hardwareAccelerationEnabled']);

  static bool get softwareRenderingFallback =>
      _boolValue(_capabilities['softwareRenderingFallback']);

  // ---------------------------------------------------------------------------
  // COMPATIBILITY
  // ---------------------------------------------------------------------------

  static bool get knownProblematicGraphicsDevice =>
      _boolValue(_capabilities['knownProblematicGraphicsDevice']);

  static bool get extremelyConstrainedDevice =>
      _boolValue(_capabilities['extremelyConstrainedDevice']);

  // ---------------------------------------------------------------------------
  // PERFORMANCE PROFILE
  // ---------------------------------------------------------------------------

  /// ULTRA
  ///
  /// Suitable for:
  /// - Rich animations
  /// - Larger images
  /// - Blur
  /// - Complex transitions
  /// - More sophisticated visual effects
  static bool get isUltra => _tier == PerformanceTier.ultra;

  /// HIGH
  static bool get isHigh => _tier == PerformanceTier.high;

  /// STANDARD
  static bool get isStandard => _tier == PerformanceTier.standard;

  /// SAFE
  static bool get isSafe => _tier == PerformanceTier.safe;

  // ---------------------------------------------------------------------------
  // UI ADAPTATION
  // ---------------------------------------------------------------------------

  /// Expensive animations can be enabled.
  static bool get enableHeavyAnimations {
    switch (_tier) {
      case PerformanceTier.ultra:
      case PerformanceTier.high:
        return true;

      case PerformanceTier.standard:
      case PerformanceTier.safe:
        return false;
    }
  }

  /// Complex route/page transitions.
  static bool get enableComplexTransitions {
    switch (_tier) {
      case PerformanceTier.ultra:
        return true;

      case PerformanceTier.high:
        return true;

      case PerformanceTier.standard:
      case PerformanceTier.safe:
        return false;
    }
  }

  /// Backdrop blur / glassmorphism.
  ///
  /// Blur can be disproportionately expensive on weaker GPUs.
  static bool get enableBlur {
    switch (_tier) {
      case PerformanceTier.ultra:
        return true;

      case PerformanceTier.high:
        return false;

      case PerformanceTier.standard:
      case PerformanceTier.safe:
        return false;
    }
  }

  /// Shadows.
  static bool get enableShadows {
    switch (_tier) {
      case PerformanceTier.ultra:
      case PerformanceTier.high:
      case PerformanceTier.standard:
        return true;

      case PerformanceTier.safe:
        return false;
    }
  }

  /// Expensive decorative gradients.
  static bool get enableComplexGradients =>
      _tier == PerformanceTier.ultra || _tier == PerformanceTier.high;

  /// Hero animations.
  static bool get enableHeroAnimations =>
      _tier == PerformanceTier.ultra || _tier == PerformanceTier.high;

  /// Animated list items.
  static bool get enableListAnimations =>
      _tier == PerformanceTier.ultra || _tier == PerformanceTier.high;

  /// Animated charts.
  static bool get enableChartAnimations =>
      _tier == PerformanceTier.ultra || _tier == PerformanceTier.high;

  /// More aggressive image resolution can be used.
  static bool get preferHighResolutionImages => _tier == PerformanceTier.ultra;

  /// Standard/high-resolution images are acceptable.
  static bool get preferStandardResolutionImages =>
      _tier == PerformanceTier.ultra || _tier == PerformanceTier.high;

  /// Use compressed/smaller image assets.
  static bool get preferLowResolutionImages =>
      _tier == PerformanceTier.standard || _tier == PerformanceTier.safe;

  /// Whether a UI component should avoid expensive painting.
  static bool get reducePaintComplexity =>
      _tier == PerformanceTier.safe || _tier == PerformanceTier.standard;

  /// Whether lists should aggressively avoid unnecessary work.
  static bool get optimizeLists => true;

  /// Number of simultaneously animated elements recommended.
  static int get recommendedConcurrentAnimations {
    switch (_tier) {
      case PerformanceTier.ultra:
        return 24;

      case PerformanceTier.high:
        return 16;

      case PerformanceTier.standard:
        return 8;

      case PerformanceTier.safe:
        return 3;
    }
  }

  /// Recommended cache extent for long scrolling lists.
  ///
  /// Smaller values reduce memory pressure.
  static double get recommendedCacheExtent {
    switch (_tier) {
      case PerformanceTier.ultra:
        return 900;

      case PerformanceTier.high:
        return 700;

      case PerformanceTier.standard:
        return 500;

      case PerformanceTier.safe:
        return 250;
    }
  }

  /// Recommended animation duration multiplier.
  ///
  /// We are not making weak devices animate "slower" arbitrarily.
  /// Instead, this lets the UI reduce animation work.
  static double get animationComplexityMultiplier {
    switch (_tier) {
      case PerformanceTier.ultra:
        return 1.0;

      case PerformanceTier.high:
        return 1.0;

      case PerformanceTier.standard:
        return 0.85;

      case PerformanceTier.safe:
        return 0.65;
    }
  }

  /// Recommended maximum image dimension for expensive UI surfaces.
  static int get recommendedImageSize {
    switch (_tier) {
      case PerformanceTier.ultra:
        return 2048;

      case PerformanceTier.high:
        return 1536;

      case PerformanceTier.standard:
        return 1024;

      case PerformanceTier.safe:
        return 768;
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER POLICIES
  // ---------------------------------------------------------------------------

  /// Returns [rich] for stronger devices and [simple] for weaker devices.
  static T choose<T>({required T rich, required T simple}) {
    if (_tier == PerformanceTier.ultra || _tier == PerformanceTier.high) {
      return rich;
    }

    return simple;
  }

  /// Returns three levels:
  ///
  /// - ultra/high  -> [high]
  /// - standard    -> [medium]
  /// - safe        -> [low]
  static T chooseThree<T>({
    required T high,
    required T medium,
    required T low,
  }) {
    switch (_tier) {
      case PerformanceTier.ultra:
      case PerformanceTier.high:
        return high;

      case PerformanceTier.standard:
        return medium;

      case PerformanceTier.safe:
        return low;
    }
  }

  // ---------------------------------------------------------------------------
  // DIAGNOSTICS
  // ---------------------------------------------------------------------------

  /// Human-readable diagnostic summary.
  static String get diagnosticSummary {
    return [
      'LoanX Device Performance',
      '-------------------------',
      'Tier: ${_tier.name}',
      'Android: $androidRelease (API $sdkInt)',
      'Device: $manufacturer $model',
      'CPU cores: $cpuCores',
      'Memory class: $memoryClassMb MB',
      'Low RAM: $isLowRamDevice',
      '64-bit: $supports64Bit',
      'OpenGL ES: $openGlEsVersion',
      'Vulkan: $supportsVulkan',
      'Hardware acceleration: $hardwareAccelerationEnabled',
      'Software fallback: $softwareRenderingFallback',
      'Known graphics issue: $knownProblematicGraphicsDevice',
      'Extremely constrained: $extremelyConstrainedDevice',
    ].join('\n');
  }

  // ---------------------------------------------------------------------------
  // INTERNAL HELPERS
  // ---------------------------------------------------------------------------

  static PerformanceTier _parseTier(dynamic value) {
    switch (value?.toString().toUpperCase()) {
      case 'ULTRA':
        return PerformanceTier.ultra;

      case 'HIGH':
        return PerformanceTier.high;

      case 'SAFE':
        return PerformanceTier.safe;

      case 'STANDARD':
      default:
        return PerformanceTier.standard;
    }
  }

  static int? _intValue(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }

  static String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((dynamic item) => item.toString())
          .toList(growable: false);
    }

    return const <String>[];
  }
}

/// Makes the startup performance profile available to every descendant UI.
///
/// The native profile is device-wide and is loaded before [runApp]. Screens
/// should use this scope when they need a context-aware decision; shared UI
/// defaults are applied by [AppTheme] at the application boundary.
class DevicePerformanceScope extends InheritedWidget {
  const DevicePerformanceScope({
    required this.tier,
    required super.child,
    super.key,
  });

  final PerformanceTier tier;

  static DevicePerformanceScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DevicePerformanceScope>() ??
      const DevicePerformanceScope(
        tier: PerformanceTier.standard,
        child: SizedBox.shrink(),
      );

  bool get reducePaintComplexity =>
      tier == PerformanceTier.standard || tier == PerformanceTier.safe;

  bool get useBasicEffects => tier == PerformanceTier.safe;

  @override
  bool updateShouldNotify(DevicePerformanceScope oldWidget) =>
      tier != oldWidget.tier;
}
