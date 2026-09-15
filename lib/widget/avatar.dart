import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:loanx/db/app_settings.dart';
import 'package:loanx/service/device_performance.dart';

class ProfilePicture extends StatelessWidget {
  final String? imageUrl;
  final String displayName;
  final double radius;

  const ProfilePicture({
    super.key,
    required this.imageUrl,
    required this.displayName,
    this.radius = 35,
  });

  @override
  Widget build(BuildContext context) {
    final imageCacheSize = _imageCacheSize(context);
    final diameter = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                imageUrl!,
                width: diameter,
                height: diameter,
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
    final logicalSize = (radius * 2).ceil();
    if (DevicePerformance.isSafe) return logicalSize * 2;
    return (logicalSize * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(logicalSize * 2, logicalSize * 6)
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
  final double radius;

  const LocalProfilePicture({
    super.key,
    required this.displayName,
    this.radius = 35,
  });

  @override
  Widget build(BuildContext context) {
    final imageCacheSize = _imageCacheSize(context);
    final diameter = radius * 2;
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.onPrimary,
      child: ClipOval(
        child: Image.memory(
          Uint8List.fromList(AppSettings.getPhoto()),
          width: diameter,
          height: diameter,
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
    final logicalSize = (radius * 2).ceil();
    if (DevicePerformance.isSafe) return logicalSize * 2;
    return (logicalSize * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(logicalSize * 2, logicalSize * 6)
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
