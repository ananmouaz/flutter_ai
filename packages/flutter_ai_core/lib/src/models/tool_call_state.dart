/// The lifecycle stage of a single tool call.
///
/// A call advances monotonically: its arguments stream in, become complete and
/// valid, the tool executes, and finally a result (or an error) is available.
enum ToolCallState {
  /// The model is still streaming the call's arguments; the JSON is partial.
  inputStreaming('input-streaming'),

  /// Arguments have fully arrived and parsed into valid JSON.
  inputAvailable('input-available'),

  /// The tool is executing.
  executing('executing'),

  /// The tool finished and produced a result.
  outputAvailable('output-available'),

  /// The call failed — argument validation or execution raised an error.
  error('error');

  const ToolCallState(this.wireName);

  /// The stable string used on the wire and in JSON.
  final String wireName;

  /// Parses a [wireName] into its [ToolCallState].
  ///
  /// Throws a [FormatException] if [value] is not a known state.
  static ToolCallState fromJson(String value) {
    for (final state in values) {
      if (state.wireName == value) return state;
    }
    throw FormatException('Unknown ToolCallState: "$value"');
  }

  /// The wire representation of this state.
  String toJson() => wireName;
}
