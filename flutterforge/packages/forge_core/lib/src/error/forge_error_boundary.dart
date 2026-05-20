import 'package:flutter/material.dart';

class ForgeErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails)? errorWidget;
  const ForgeErrorBoundary({super.key, required this.child, this.errorWidget});
  @override State<ForgeErrorBoundary> createState() => _ForgeErrorBoundaryState();
}

class _ForgeErrorBoundaryState extends State<ForgeErrorBoundary> {
  FlutterErrorDetails? _errorDetails;
  @override void initState() {
    super.initState();
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      original?.call(details);
      if (mounted) setState(() => _errorDetails = details);
    };
  }
  @override Widget build(BuildContext context) {
    if (_errorDetails != null) {
      return widget.errorWidget?.call(_errorDetails!) ?? Scaffold(
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Something went wrong', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_errorDetails!.exceptionAsString(), textAlign: TextAlign.center),
        ])),
      );
    }
    return widget.child;
  }
}
