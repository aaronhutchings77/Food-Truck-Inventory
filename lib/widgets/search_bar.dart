import 'package:flutter/material.dart';

class CustomSearchBar extends StatefulWidget {
  final String labelText;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const CustomSearchBar({
    super.key,
    required this.labelText,
    required this.controller,
    this.onChanged,
    this.onClear,
  });

  @override
  State<CustomSearchBar> createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _currentText = widget.controller.text;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final newText = widget.controller.text;
    if (newText != _currentText) {
      setState(() {
        _currentText = newText;
      });
      if (widget.onChanged != null) {
        widget.onChanged!(newText);
      }
    }
  }

  void _handleClear() {
    widget.controller.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _currentText = '';
    });
    if (widget.onClear != null) {
      widget.onClear!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      decoration: InputDecoration(
        labelText: widget.labelText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _currentText.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: _handleClear)
            : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
