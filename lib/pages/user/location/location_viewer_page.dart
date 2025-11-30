import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationViewerPage extends StatefulWidget {
  const LocationViewerPage({super.key});

  @override
  State<LocationViewerPage> createState() => _LocationViewerPageState();
}

//homepage usesage

class _LocationViewerPageState extends State<LocationViewerPage> {
  GoogleMapController? _mapController;
  LatLng? _location;
  String _locationName = 'Fetching location...';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGPSLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _fetchGPSLocation() async {
    try {
      //check location services 
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _error = 'Location services disabled';
          _isLoading = false;
          _locationName = 'Location services disabled';
        });
        return;
      }

      // check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _error = 'Location permission denied';
          _isLoading = false;
          _locationName = 'Location permission denied';
        });
        return;
      }

      //current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      //convert coordinates to address
      String locationLabel;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final parts = <String>[];
          
          //add street address 
          if ((place.street ?? '').isNotEmpty) {
            parts.add(place.street!);
          } else if ((place.subThoroughfare ?? '').isNotEmpty || 
                     (place.thoroughfare ?? '').isNotEmpty) {
            final streetParts = <String>[];
            if ((place.subThoroughfare ?? '').isNotEmpty) {
              streetParts.add(place.subThoroughfare!);
            }
            if ((place.thoroughfare ?? '').isNotEmpty) {
              streetParts.add(place.thoroughfare!);
            }
            if (streetParts.isNotEmpty) {
              parts.add(streetParts.join(' '));
            }
          }
          
          //sub-locality
          if ((place.subLocality ?? '').isNotEmpty) {
            parts.add(place.subLocality!);
          }
          //city
          if ((place.locality ?? '').isNotEmpty) {
            parts.add(place.locality!);
          }
          //postal code
          if ((place.postalCode ?? '').isNotEmpty) {
            parts.add(place.postalCode!);
          }
          //state
          if ((place.administrativeArea ?? '').isNotEmpty) {
            parts.add(place.administrativeArea!);
          }
          //country
          if ((place.country ?? '').isNotEmpty) {
            parts.add(place.country!);
          }
          
          locationLabel = parts.where((p) => p.trim().isNotEmpty).join(', ');
          
          //use formatted address
          if (locationLabel.isEmpty && (place.name ?? '').isNotEmpty) {
            locationLabel = place.name!;
          }
        } else {
          locationLabel =
              '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
        }
      } catch (_) {
        //used coordinates if geocoding fails
        locationLabel =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }

      if (!mounted) return;
      setState(() {
        _location = LatLng(position.latitude, position.longitude);
        _locationName = locationLabel;
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to fetch location';
        _isLoading = false;
        _locationName = 'Unable to fetch location';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Location',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C8A0).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFF00C8A0),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Location',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _locationName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C8A0),
                    ),
                  )
                : _location != null
                    ? GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _location!,
                          zoom: 14,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('current_location'),
                            position: _location!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ),
                            infoWindow: InfoWindow(
                              title: 'Your Location',
                              snippet: _locationName,
                            ),
                          ),
                        },
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        mapToolbarEnabled: false,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _error ?? 'Location coordinates not available',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _fetchGPSLocation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00C8A0),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

