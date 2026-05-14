import 'package:flutter/material.dart';
import '../../data/services/alert_service.dart';
import 'auth/login_screen.dart'; // Make sure this path points to your login screen

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AlertService _alertService = AlertService();
  List<dynamic> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  // Function to load data from the service
  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final alerts = await _alertService.fetchAlerts();
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Function to handle logout securely
  void _handleLogout() async {
    await _alertService.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Smart Home Command'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAlerts, // Manually refresh alerts
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout, // Secure logout
          ),
        ],
      ),
      body: Column(
        children: [
          // --- TOP SECTION: Camera Feed Placeholder ---
          Container(
            height: 220,
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.videocam, color: Colors.white54, size: 50),
                  SizedBox(height: 10),
                  Text(
                    'CCTV Feed Offline\n(RTSP Integration Pending)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),

          // --- MIDDLE SECTION: Status Title ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Recent AI Detections',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // --- BOTTOM SECTION: The Alert List ---
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _alerts.isEmpty
                        ? const Center(child: Text('No intruders detected.'))
                        : ListView.builder(
                            itemCount: _alerts.length,
                            itemBuilder: (context, index) {
                              final alert = _alerts[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    backgroundColor: Colors.redAccent,
                                    child: Icon(Icons.person, color: Colors.white),
                                  ),
                                  // Assumes your backend returns 'event_type' and 'confidence_score'
                                  title: Text(alert['event_type'] ?? 'Unknown Event'),
                                  subtitle: Text('Confidence: ${(alert['confidence_score'] * 100).toStringAsFixed(1)}%'),
                                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}