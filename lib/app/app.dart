import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'router.dart';
import 'theme.dart';

class FluxVisionApp extends StatefulWidget {
  const FluxVisionApp({super.key});

  @override
  State<FluxVisionApp> createState() => _FluxVisionAppState();
}

class _FluxVisionAppState extends State<FluxVisionApp> {
  late final GoRouter _router = buildAppRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FluxVision',
      debugShowCheckedModeBanner: false,
      theme: FluxTheme.dark(),
      routerConfig: _router,
    );
  }
}
