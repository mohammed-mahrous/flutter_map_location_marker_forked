import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

class GeolocatorSettingsExample extends StatelessWidget {
  final _positionStream =
      const LocationMarkerDataStreamFactory().fromGeolocatorPositionStream(
    stream: Location().onLocationChanged,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geolocator Settings Example'),
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(0, 0),
          initialZoom: 1,
          minZoom: 0,
          maxZoom: 19,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:
                'net.tlserver6y.flutter_map_location_marker.example',
            maxZoom: 19,
          ),
          CurrentLocationLayer(
            positionStream: _positionStream,
          ),
        ],
      ),
    );
  }
}
