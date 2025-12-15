import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dialog_utils.dart';

class MapHelper {
  static const LatLng defaultCenter = LatLng(2.7456, 101.7072);
  static const double defaultZoom = 5.0;
  static LatLngBounds calculateBounds(List<LatLng> positions) {
    if (positions.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(-90, -180),
        northeast: const LatLng(90, 180),
      );
    }
    
    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;
    
    for (final position in positions) {
      minLat = minLat < position.latitude ? minLat : position.latitude;
      maxLat = maxLat > position.latitude ? maxLat : position.latitude;
      minLng = minLng < position.longitude ? minLng : position.longitude;
      maxLng = maxLng > position.longitude ? maxLng : position.longitude;
    }
    
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  static CameraPosition getInitialCameraPosition(List<LatLng> positions) {
    if (positions.isEmpty) {
      return const CameraPosition(
        target: defaultCenter,
        zoom: defaultZoom,
      );
    }
    
    if (positions.length == 1) {
      return CameraPosition(
        target: positions.first,
        zoom: 15.0,
      );
    }
    
    final bounds = calculateBounds(positions);
    final center = LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
    
    return CameraPosition(
      target: center,
      zoom: 10.0,
    );
  }
  
  static void showMapError(BuildContext context, String message) {
    DialogUtils.showWarningMessage(
      context: context,
      message: message,
      duration: const Duration(seconds: 5),
    );
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
          point1.latitude,
          point1.longitude,
          point2.latitude,
          point2.longitude,
        ) /
        1000; 
  }

  static Future<BitmapDescriptor> createDotMarker(
    Color color, {
    int size = 96,
  }) async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);
    final ui.Paint paint = ui.Paint()..color = color;
    final double radius = size / 2.0;

    final ui.Paint glow = ui.Paint()
      ..color = color.withOpacity(0.25)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6);
    canvas.drawCircle(ui.Offset(radius, radius), radius * 0.9, glow);

    canvas.drawCircle(ui.Offset(radius, radius), radius * 0.55, paint);

    final ui.Image image = await recorder.endRecording().toImage(size, size);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  static Future<bool> safeCameraOperation(
    GoogleMapController controller,
    Future<void> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        await Future.delayed(initialDelay * (attempt + 1));
        await operation();
        return true;
      } catch (e) {
        debugPrint('Camera operation attempt ${attempt + 1} failed: $e');
        if (attempt == maxRetries - 1) {
          return false;
        }
      }
    }
    return false;
  }
}


