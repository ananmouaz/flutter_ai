// Declares a tool, advertises it, and fulfills a tool call.
//
// Run with: dart run example/flutter_ai_tools_example.dart
import 'package:flutter_ai_tools/flutter_ai_tools.dart';

Future<void> main() async {
  final tools = ToolRegistry([
    ToolSpec(
      name: 'get_weather',
      description: 'Get the current weather for a city',
      parametersSchema: const {
        'type': 'object',
        'properties': {
          'city': {'type': 'string'},
        },
        'required': ['city'],
      },
      execute: (args) async {
        final city = args['city']! as String;
        // Pretend to call a weather API.
        return {'city': city, 'tempC': 21, 'condition': 'Cloudy'};
      },
    ),
  ]);

  // These definitions are what you pass to an LlmProvider / UseChatController.
  print('Advertised tools: ${tools.definitions.map((d) => d.name).toList()}');

  // Simulate a tool call the model emitted, then fulfill it.
  const call = ToolCallPart(
    toolCallId: 'call-1',
    toolName: 'get_weather',
    args: {'city': 'London'},
    state: ToolCallState.inputAvailable,
  );

  final result = await tools.run(call);
  print('Result (isError=${result.isError}): ${result.result}');
}
