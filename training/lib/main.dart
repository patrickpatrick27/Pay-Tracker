import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NAP Box Locator',
      debugShowCheckedModeBanner: false, // Removes the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  // Data State
  List<dynamic> _allLcps = [];
  List<dynamic> _searchResults = []; // For the drop-down list
  List<Marker> _markers = [];
  dynamic _selectedLcp;

  // Initial Center (Tagaytay)
  final LatLng _initialCenter = const LatLng(14.1153, 120.9621);
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 1. Load Data
  Future<void> _loadData() async {
    try {
      final String response = await rootBundle.loadString('assets/lcp_data.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _allLcps = data;
        _resetToOverview(); // Start clean
      });
    } catch (e) {
      debugPrint("Error loading data: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Migrated': return Colors.green;
      case 'Pending': return Colors.red;
      case 'Partially Migrated': return Colors.orange;
      default: return Colors.grey;
    }
  }

  // 2. MODE: Overview (Show all LCPs)
  void _resetToOverview() {
    _generateOverviewMarkers(_allLcps); // Show all markers
    setState(() {
      _selectedLcp = null;
      _searchResults.clear();
      _isSearching = false;
    });
    // Don't move camera automatically here, let user pan/zoom
  }

  // Helper to generate markers for a list of LCPs
  void _generateOverviewMarkers(List<dynamic> lcps) {
    List<Marker> markers = [];
    for (var lcp in lcps) {
      if (lcp['nps'] != null && lcp['nps'].isNotEmpty) {
        var firstNp = lcp['nps'][0];
        markers.add(
          Marker(
            point: LatLng(firstNp['lat'], firstNp['lng']),
            width: 40,
            height: 40,
            child: GestureDetector(
              onTap: () => _focusOnLcp(lcp), // User must TAP to see details
              child: Icon(
                Icons.location_on, 
                color: _getStatusColor(lcp['status']), 
                size: 40
              ),
            ),
          ),
        );
      }
    }
    setState(() => _markers = markers);
  }

  // 3. MODE: Focus (Zoom in on one LCP)
  void _focusOnLcp(dynamic lcp) {
    // 1. Close keyboard and search list
    FocusScope.of(context).unfocus(); 
    setState(() {
      _isSearching = false;
      _selectedLcp = lcp;
    });

    List<Marker> npMarkers = [];
    List<LatLng> pointsForBounds = [];

    // 2. Create detailed markers for NPs
    for (var np in lcp['nps']) {
      double lat = np['lat'];
      double lng = np['lng'];
      LatLng pos = LatLng(lat, lng);
      pointsForBounds.add(pos);

      npMarkers.add(
        Marker(
          point: pos,
          width: 80, // Wider for text
          height: 60,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  np['name'],
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(
                Icons.radio_button_checked,
                color: _getStatusColor(lcp['status']), 
                size: 25
              ),
            ],
          ),
        ),
      );
    }

    setState(() => _markers = npMarkers);

    // 3. Zoom Camera
    if (pointsForBounds.isNotEmpty) {
       double minLat = pointsForBounds.first.latitude;
       double maxLat = pointsForBounds.first.latitude;
       double minLng = pointsForBounds.first.longitude;
       double maxLng = pointsForBounds.first.longitude;

       for (var p in pointsForBounds) {
         if (p.latitude < minLat) minLat = p.latitude;
         if (p.latitude > maxLat) maxLat = p.latitude;
         if (p.longitude < minLng) minLng = p.longitude;
         if (p.longitude > maxLng) maxLng = p.longitude;
       }
       
       // Add slight padding to bounds
       _mapController.fitCamera(
         CameraFit.bounds(
           bounds: LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng)),
           padding: const EdgeInsets.all(80), 
         ),
       );
    }

    // 4. Show Details (Only NOW do we show the menu)
    _showDetailsBottomSheet(lcp);
  }

  // 4. Search Logic
  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      _resetToOverview();
      return;
    }

    setState(() => _isSearching = true);

    final filtered = _allLcps.where((lcp) {
      final name = lcp['lcp_name'].toString().toLowerCase();
      final site = lcp['site_name'].toString().toLowerCase();
      return name.contains(query.toLowerCase()) || site.contains(query.toLowerCase());
    }).toList();

    setState(() => _searchResults = filtered);
    
    // Also update map markers to show only matches, BUT DO NOT ZOOM YET
    _generateOverviewMarkers(filtered);
  }

  // 5. Details Menu
  void _showDetailsBottomSheet(dynamic lcp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Floating look
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.6,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 40, height: 4, 
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 15),
                  Text(lcp['lcp_name'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text(lcp['site_name'], style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 10),
                  Chip(
                    label: Text(lcp['status'], style: const TextStyle(color: Colors.white)),
                    backgroundColor: _getStatusColor(lcp['status']),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: lcp['nps'].length,
                      itemBuilder: (context, index) {
                        var np = lcp['nps'][index];
                        return ListTile(
                          leading: const Icon(Icons.my_location),
                          title: Text(np['name']),
                          subtitle: Text("${np['lat']}, ${np['lng']}"),
                          dense: true,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Optional: When menu closes, stay zoomed in? Or reset?
      // Uncomment below to auto-reset when closing menu:
      // _resetToOverview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, __) {
                 // Tapping map closes search list
                 if (_isSearching) setState(() => _isSearching = false);
                 FocusScope.of(context).unfocus();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.davepatrick.napboxlocator',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // 2. SEARCH INTERFACE
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Column(
              children: [
                // Search Bar
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: "Search NAP Box...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear), 
                            onPressed: () {
                              _searchController.clear();
                              _resetToOverview();
                              _mapController.move(_initialCenter, 13.0);
                            },
                          ) 
                        : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(15),
                    ),
                    onChanged: _onSearchChanged,
                    onTap: () {
                       if (_searchController.text.isNotEmpty) {
                         setState(() => _isSearching = true);
                       }
                    },
                  ),
                ),

                // 3. SEARCH RESULTS LIST (Only visible when searching)
                if (_isSearching && _searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    height: 250, // Limit height so map is still visible
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(blurRadius: 5, color: Colors.black26)],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var lcp = _searchResults[index];
                        return ListTile(
                          title: Text(lcp['lcp_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(lcp['site_name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                          leading: Icon(Icons.location_on, color: _getStatusColor(lcp['status'])),
                          onTap: () {
                            // HERE is the click-to-go logic
                            _focusOnLcp(lcp);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          
          // 4. BACK BUTTON (Only when focused)
          if (_selectedLcp != null && !_isSearching)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                   _resetToOverview();
                   _mapController.move(_initialCenter, 13.0);
                },
                label: const Text("Reset Map"),
                icon: const Icon(Icons.map),
              ),
            ),
        ],
      ),
    );
  }
}