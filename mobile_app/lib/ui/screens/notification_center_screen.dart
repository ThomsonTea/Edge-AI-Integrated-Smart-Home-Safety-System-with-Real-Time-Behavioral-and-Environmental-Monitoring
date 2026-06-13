import 'package:flutter/material.dart';

import '../../routing/routes.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../widgets/ai_event_list.dart';

class NotificationCenterScreen extends StatefulWidget {
  final bool showAppBar;

  const NotificationCenterScreen({super.key, this.showAppBar = false});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationViewModel _viewModel = NotificationViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelUpdate);
    _viewModel.loadNotifications();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  void _onViewModelUpdate() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    if (!widget.showAppBar) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Center')),
      body: content,
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.errorMessage != null && _viewModel.events.isEmpty) {
      return _NotificationErrorState(
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.loadNotifications,
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.refreshNotifications,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notification Center (${_viewModel.events.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (_viewModel.isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (_viewModel.errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              'Error: ${_viewModel.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          ],
          const SizedBox(height: 12),
          if (_viewModel.events.isEmpty)
            const _EmptyNotificationState()
          else
            AiEventList(
              events: _viewModel.events,
              onEventTap: (event) {
                Navigator.of(
                  context,
                ).pushNamed(AppRoutes.eventDetail, arguments: event.id);
              },
            ),
        ],
      ),
    );
  }
}

class _NotificationErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NotificationErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Error: $message',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.35,
      child: const Center(
        child: Text('No notifications yet', textAlign: TextAlign.center),
      ),
    );
  }
}
