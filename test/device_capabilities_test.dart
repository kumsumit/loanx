import 'package:flutter_test/flutter_test.dart';
import 'package:loanx/service/device_capabilities.dart';

void main() {
  DeviceCapabilities profile({
    int sdk = 35,
    int memory = 256,
    bool lowRam = false,
    bool is64Bit = true,
    int glEs = 3,
  }) => DeviceCapabilities(
    isAndroid: true,
    sdkInt: sdk,
    memoryClassMb: memory,
    isLowRamDevice: lowRam,
    supports64Bit: is64Bit,
    openGlEsMajor: glEs,
  );

  test('Samsung J2 class profile uses conservative effects', () {
    expect(
      profile(sdk: 25, memory: 128, is64Bit: false, glEs: 3).renderingTier,
      RenderingTier.conservative,
    );
  });

  test('old Android alone does not force conservative effects', () {
    expect(
      profile(sdk: 25, is64Bit: true, glEs: 3).renderingTier,
      RenderingTier.compatible,
    );
  });

  test('modern 32-bit devices retain their full visual tier', () {
    expect(
      profile(sdk: 30, is64Bit: false, glEs: 3).renderingTier,
      RenderingTier.full,
    );
  });

  test('limited graphics receives compatible effects independent of RAM', () {
    expect(
      profile(memory: 512, glEs: 2).renderingTier,
      RenderingTier.compatible,
    );
  });
}
