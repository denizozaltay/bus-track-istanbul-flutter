import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bustrackistanbul/services/iett.dart';
import 'package:latlong2/latlong.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  TextEditingController busCodeController = TextEditingController();
  TextEditingController directionController =
      TextEditingController(text: "departure");

  LatLng? currentLocation;

  Future<List<List<dynamic>>>? busStopsFuture;
  Future<List<List<dynamic>>>? busLocationsFuture;

  IETT iett = IETT();

  String? selectedBusStop;

  MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  void openBusSelectionBox() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: const Text(
          'Select Bus Line',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: busCodeController,
                decoration: InputDecoration(
                  labelText: "Bus Line",
                  hintText: "e.g. 50D",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  prefixIcon:
                      const Icon(Icons.directions_bus, color: Colors.blue),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: DropdownButtonFormField<String>(
                value: directionController.text.isEmpty
                    ? "departure"
                    : directionController.text,
                decoration: InputDecoration(
                  labelText: "Direction",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  prefixIcon:
                      const Icon(Icons.compare_arrows, color: Colors.blue),
                ),
                items: const [
                  DropdownMenuItem(
                    value: "departure",
                    child: Text("Departure"),
                  ),
                  DropdownMenuItem(
                    value: "return",
                    child: Text("Return"),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    directionController.text = newValue!;
                  });
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              final directionCode =
                  directionController.text == "departure" ? "G" : "D";
              final stopsFuture =
                  iett.getLineStops(busCodeController.text, directionCode);
              final locationsFuture =
                  iett.getBusLocations(busCodeController.text, directionCode);

              setState(() {
                busStopsFuture = stopsFuture;
                busLocationsFuture = locationsFuture;
              });

              stopsFuture.then(
                (stops) {
                  if (!mounted || busStopsFuture != stopsFuture) return;
                  _focusMapOnBusStops(stops);
                },
                onError: (error) {
                  debugPrint('Unable to zoom to bus line: $error');
                },
              );
              Navigator.pop(context);
            },
            child: const Text("Select"),
          ),
        ],
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    try {
      await Geolocator.requestPermission();

      final location = await Geolocator.getCurrentPosition();
      setState(() {
        currentLocation = LatLng(location.latitude, location.longitude);
      });
    } catch (e) {
      if (e is PermissionDeniedException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Location permission denied"),
                ],
              ),
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _getCurrentLocation(),
              ),
            ),
          );
        }
      }
    }
  }

  void _focusMapOnBusStops(List<List<dynamic>> stops) {
    final points = <LatLng>[];

    for (final stop in stops) {
      if (stop.length < 3) continue;
      final lat = double.tryParse(stop[1].toString());
      final lon = double.tryParse(stop[2].toString());
      if (lat == null || lon == null) continue;
      points.add(LatLng(lat, lon));
    }

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      mapController.move(points.first, 15);
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);

    mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Colors.blue,
              ),
              SizedBox(height: 16),
              Text(
                'Getting your location...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation!,
              initialZoom: 12.6,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png",
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    width: 80.0,
                    height: 80.0,
                    point: currentLocation!,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 40,
                    ),
                  ),
                ],
              ),
              if (selectedBusStop != null)
                Positioned(
                  top: 80,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            spreadRadius: 2,
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            selectedBusStop!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              FutureBuilder<List<List<dynamic>>>(
                future: busStopsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const MarkerLayer(markers: []);
                  } else if (snapshot.hasError) {
                    return const MarkerLayer(markers: []);
                  } else {
                    var busStops = snapshot.data;
                    List<Marker> markers = [];

                    if (busStops != null) {
                      for (var location in busStops) {
                        markers.add(
                          Marker(
                            width: 80.0,
                            height: 80.0,
                            point: LatLng(
                              double.parse(location[1]),
                              double.parse(location[2]),
                            ),
                            child: GestureDetector(
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 35,
                              ),
                              onTap: () {
                                setState(() {
                                  selectedBusStop = location[0];
                                });
                              },
                            ),
                          ),
                        );
                      }
                    }
                    return MarkerLayer(markers: markers);
                  }
                },
              ),
              FutureBuilder<List<List<dynamic>>>(
                future: busLocationsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const MarkerLayer(markers: []);
                  } else if (snapshot.hasError) {
                    return const MarkerLayer(markers: []);
                  } else {
                    var busLocations = snapshot.data;
                    List<Marker> markers = [];

                    if (busLocations != null) {
                      for (var location in busLocations) {
                        markers.add(
                          Marker(
                            width: 120.0,
                            height: 120.0,
                            point: LatLng(
                              double.parse(location[1]),
                              double.parse(location[2]),
                            ),
                            child: const Icon(
                              Icons.directions_bus,
                              color: Colors.blue,
                              size: 30,
                            ),
                          ),
                        );
                      }
                    }
                    return MarkerLayer(markers: markers);
                  }
                },
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: SpeedDial(
        animatedIcon: AnimatedIcons.menu_close,
        backgroundColor: Colors.blue,
        overlayColor: Colors.black,
        overlayOpacity: 0.4,
        spacing: 8,
        spaceBetweenChildren: 8,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.directions_bus),
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            label: 'Select Bus Line',
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            labelBackgroundColor: Colors.white,
            onTap: openBusSelectionBox,
          ),
          SpeedDialChild(
            child: const Icon(Icons.refresh),
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            label: 'Refresh Bus Locations',
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            labelBackgroundColor: Colors.white,
            onTap: () {
              setState(() {
                busLocationsFuture = iett.getBusLocations(
                    busCodeController.text,
                    directionController.text == "departure" ? "G" : "D");
              });
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.location_on),
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue,
            label: 'Get Current Location',
            labelStyle: const TextStyle(fontWeight: FontWeight.w500),
            labelBackgroundColor: Colors.white,
            onTap: () {
              setState(() {
                _getCurrentLocation();
                mapController.move(currentLocation!, 13.6);
              });
            },
          ),
        ],
      ),
    );
  }
}
