import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef _OpenNative = Int32 Function(Pointer<Utf8>, Int32);
typedef _OpenDart = int Function(Pointer<Utf8>, int);
typedef _DescriptorNative = Int32 Function(Int32);
typedef _DescriptorDart = int Function(int);

/// Persists directory-entry changes made by rename/delete operations.
///
/// File.flush() syncs file contents, but a sudden power loss can still discard
/// the rename which made that file current. POSIX directory fsync closes that
/// final durability window on LoanX's Android and Apple targets.
Future<void> syncDirectoryMetadata(Directory directory) async {
  if (!(Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isLinux ||
      Platform.isMacOS)) {
    return;
  }

  final libc = DynamicLibrary.process();
  final open = libc.lookupFunction<_OpenNative, _OpenDart>('open');
  final fsync = libc.lookupFunction<_DescriptorNative, _DescriptorDart>(
    'fsync',
  );
  final close = libc.lookupFunction<_DescriptorNative, _DescriptorDart>(
    'close',
  );
  final nativePath = directory.path.toNativeUtf8();
  final directoryFlag = Platform.isMacOS || Platform.isIOS
      ? 0x100000
      : Platform.isAndroid
      ? 0x4000
      : 0x10000;
  final descriptor = open(nativePath, directoryFlag);
  malloc.free(nativePath);
  if (descriptor < 0) {
    throw FileSystemException(
      'Could not open directory for durability sync',
      directory.path,
    );
  }

  try {
    if (fsync(descriptor) != 0) {
      throw FileSystemException(
        'Could not sync directory metadata',
        directory.path,
      );
    }
  } finally {
    close(descriptor);
  }
}
