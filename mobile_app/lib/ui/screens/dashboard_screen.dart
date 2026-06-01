import 'package:flutter/material.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../widgets/camera_widget.dart';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _viewModel = DashboardViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.initializeDashboard();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    setState(() {});
  }

  void _handleLogout() async {
    await _viewModel.logout();
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
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _viewModel.loadAlerts,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            CameraWidget(jwtToken: _viewModel.jwtToken),
            _buildAlertsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection() {
    if (_viewModel.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: CircularProgressIndicator(),
      );
    }

    if (_viewModel.errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Error: ${_viewModel.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _viewModel.loadAlerts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_viewModel.alerts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No alerts found'),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Alerts (${_viewModel.alerts.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _viewModel.alerts.length,
            itemBuilder: (context, index) {
              return _buildAlertItem(_viewModel.alerts[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(dynamic alert) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              alert['type']?.toString() ?? 'Unknown Alert',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              alert['timestamp']?.toString() ?? 'No timestamp',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
