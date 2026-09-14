import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/device_capabilities.dart';

class ProfilePicture extends StatelessWidget {
  final String? imageUrl;
  final String displayName;

  const ProfilePicture({
    super.key,
    required this.imageUrl,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final imageCacheSize = _imageCacheSize(context);
    return CircleAvatar(
      radius: 35,
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                cacheWidth: imageCacheSize,
                cacheHeight: imageCacheSize,
                filterQuality: FilterQuality.low,
                errorBuilder:
                    (
                      BuildContext context,
                      Object exception,
                      StackTrace? stackTrace,
                    ) {
                      return _buildInitialsAvatar();
                    },
              ),
            )
          : _buildInitialsAvatar(),
    );
  }

  int _imageCacheSize(BuildContext context) {
    if (DeviceCapabilitiesScope.of(context).useBasicEffects) return 140;
    return (70 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(140, 420)
        .toInt();
  }

  Widget _buildInitialsAvatar() {
    String initials = "";
    if (displayName.isEmpty) {
      return Icon(Icons.person);
    } else if (displayName.length < 2) {
      initials = displayName.toUpperCase();
    } else if (displayName.split(' ').length == 1) {
      initials = displayName.split(' ')[0].toUpperCase();
    } else {
      final String firstName = displayName.split(' ')[0];
      final String lastName = displayName.split(' ')[1];
      initials = '${firstName[0].toUpperCase()}${lastName[0].toUpperCase()}';
    }
    return Text(
      initials,
      style: TextStyle(
        // color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class LocalProfilePicture extends StatelessWidget {
  final String displayName;
  const LocalProfilePicture({super.key, required this.displayName});

  @override
  Widget build(BuildContext context) {
    final imageCacheSize = _imageCacheSize(context);
    return CircleAvatar(
      radius: 35,
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
      child: ClipOval(
        child: Image.memory(
          Uint8List.fromList(AppSettings.getPhoto()),
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          // Local photos can originate from an arbitrary camera resolution.
          // Decode only what this avatar can display, with a lower cap on the
          // conservative device profile.
          cacheWidth: imageCacheSize,
          cacheHeight: imageCacheSize,
          filterQuality: FilterQuality.low,
          errorBuilder:
              (BuildContext context, Object exception, StackTrace? stackTrace) {
                return _buildInitialsAvatar();
              },
        ),
      ),
    );
  }

  int _imageCacheSize(BuildContext context) {
    if (DeviceCapabilitiesScope.of(context).useBasicEffects) return 140;
    return (70 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(140, 420)
        .toInt();
  }

  Widget _buildInitialsAvatar() {
    String initials = "";
    if (displayName.isEmpty) {
      return Icon(Icons.person);
    } else if (displayName.length < 2) {
      initials = displayName.toUpperCase();
    } else if (displayName.split(' ').length == 1) {
      initials = displayName.split(' ')[0].toUpperCase();
    } else {
      final String firstName = displayName.split(' ')[0];
      final String lastName = displayName.split(' ')[1];
      initials = '${firstName[0].toUpperCase()}${lastName[0].toUpperCase()}';
    }
    return Text(
      initials,
      style: TextStyle(
        // color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
