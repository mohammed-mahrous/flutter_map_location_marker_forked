import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../exceptions/incorrect_setup_exception.dart';
import '../exceptions/permission_denied_exception.dart' as lm;
import '../exceptions/permission_requesting_exception.dart' as lm;
import '../exceptions/service_disabled_exception.dart';
import '../widgets/current_location_layer.dart';
import 'data.dart';

/// Signature for callbacks of permission request.
typedef RequestPermissionCallback = FutureOr<PermissionStatus> Function();

/// Helper class for converting the data stream which provide data in required
/// format from stream created by some existing plugin.
class LocationMarkerDataStreamFactory {
  /// Create a LocationMarkerDataStreamFactory.
  const LocationMarkerDataStreamFactory();

  /// Cast to a position stream from
  /// [geolocator](https://pub.dev/packages/geolocator) stream.
  Stream<LocationMarkerPosition?> fromGeolocatorPositionStream({
    Stream<LocationData?>? stream,
  }) =>
      (stream ?? defaultPositionStreamSource()).map(
        (position) => position != null
            ? LocationMarkerPosition(
                latitude: position.latitude!,
                longitude: position.longitude!,
                accuracy: position.accuracy!,
              )
            : null,
      );

  /// Create a position stream which is used as default value of
  /// [CurrentLocationLayer.positionStream].
  Stream<LocationData?> defaultPositionStreamSource({
    RequestPermissionCallback? requestPermissionCallback,
  }) {
    requestPermissionCallback ??= Location().requestPermission;
    final cancelFunctions = <AsyncCallback>[];
    final streamController = StreamController<LocationData?>.broadcast();
    final location = Location();
    streamController
      ..onListen = () async {
        try {
          var permission = await location.hasPermission();
          if (permission == PermissionStatus.denied &&
              requestPermissionCallback != null) {
            streamController.sink
                .addError(const lm.PermissionRequestingException());
            permission = await requestPermissionCallback();
          }
          switch (permission) {
            case PermissionStatus.denied:
            case PermissionStatus.deniedForever:
              if (streamController.isClosed) {
                break;
              }
              streamController.sink
                  .addError(const lm.PermissionDeniedException());
              await streamController.close();
            case PermissionStatus.grantedLimited:
            case PermissionStatus.granted:
              try {
                final serviceEnabled = await location.serviceEnabled();
                if (streamController.isClosed) {
                  break;
                }
                if (!serviceEnabled) {
                  streamController.sink
                      .addError(const ServiceDisabledException());
                }
              } on Exception catch (_) {}
              try {
                // The concept of location service doesn't exist on the web
                // platform
                if (!kIsWeb) {
                  final subscription = location
                      .serviceEnabled()
                      .asStream()
                      .listen((serviceStatus) {
                    if (serviceStatus) {
                      streamController.sink.add(null);
                    } else {
                      streamController.sink
                          .addError(const ServiceDisabledException());
                    }
                  });
                  cancelFunctions.add(subscription.cancel);
                }
              } on Exception catch (_) {}
              try {
                // getLastKnownPosition is not supported on the web platform
                if (!kIsWeb) {
                  final lastKnown = await location.onLocationChanged.last;
                  if (streamController.isClosed) {
                    break;
                  }
                  streamController.sink.add(lastKnown);
                }
              } on Exception catch (_) {}
              try {
                final serviceEnabled = await location.serviceEnabled();
                if (serviceEnabled) {
                  final position = await location.getLocation();
                  if (streamController.isClosed) {
                    break;
                  }
                  streamController.sink.add(position);
                }
              } on Exception catch (_) {}
              final subscription =
                  location.onLocationChanged.listen((position) {
                streamController.sink.add(position);
              });
              cancelFunctions.add(subscription.cancel);
          }
        } catch (e) {
          streamController.sink.addError(const IncorrectSetupException());
        }
      }
      ..onCancel = () async {
        await Future.wait(cancelFunctions.map((callback) => callback()));
        await streamController.close();
      };
    return streamController.stream;
  }

  /// Cast to a heading stream from
  /// [flutter_rotation_sensor](https://pub.dev/packages/flutter_rotation_sensor) stream.
  Stream<LocationMarkerHeading?> fromRotationSensorHeadingStream({
    Stream<OrientationEvent>? stream,
    double minAccuracy = pi * 0.1,
    double defAccuracy = pi * 0.3,
    double maxAccuracy = pi * 0.4,
  }) =>
      (stream ?? defaultHeadingStreamSource()).map(
        (e) => LocationMarkerHeading(
          heading: e.eulerAngles.azimuth,
          accuracy: e.accuracy >= 0
              ? degToRadian(e.accuracy).clamp(minAccuracy, maxAccuracy)
              : defAccuracy,
        ),
      );

  /// Create a heading stream which is used as default value of
  /// [CurrentLocationLayer.headingStream].
  Stream<OrientationEvent> defaultHeadingStreamSource() =>
      RotationSensor.orientationStream;
}
