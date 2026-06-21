import 'package:flutter/material.dart';

class AlertSearchField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const AlertSearchField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<AlertSearchField> createState() => _AlertSearchFieldState();
}

class _AlertSearchFieldState extends State<AlertSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant AlertSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Search alerts, people, premises',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: widget.value.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () => widget.onChanged(''),
              ),
      ),
    );
  }
}
