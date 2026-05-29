import 'package:flutter/material.dart';

class LazyWidget extends StatefulWidget {
  final Future<void> Function() loader;
  final Widget Function() builder;
  final bool eager;

  const LazyWidget({
    super.key,
    required this.loader,
    required this.builder,
    this.eager = false,
  });

  @override
  State<LazyWidget> createState() => _LazyWidgetState();
}

class _LazyWidgetState extends State<LazyWidget> {
  bool _loaded = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.eager) {
      _load();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load() async {
    if (_loaded || _loading) return;
    setState(() => _loading = true);
    await widget.loader();
    if (mounted) setState(() {
      _loaded = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded) return widget.builder();
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return const SizedBox.shrink();
  }
}
