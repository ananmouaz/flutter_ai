import 'package:flutter/widgets.dart';
import 'package:flutter_ai_demo/production/production_app.dart';

/// Entry point for the production conversation recipe.
void main() =>
    runApp(const ProductionAgentApp(rtl: bool.fromEnvironment('RTL')));
