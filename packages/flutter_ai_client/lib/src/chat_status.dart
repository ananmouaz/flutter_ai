/// The lifecycle state of a chat turn driven by a controller.
enum ChatStatus {
  /// No request is in flight.
  idle,

  /// A request has been sent but no events have arrived yet.
  submitted,

  /// Events are actively streaming in.
  streaming,

  /// The model's stream finished with tool calls and the agent loop is running
  /// the tool executor before re-prompting. The turn is still in flight.
  executingTools,

  /// The last request failed.
  error;

  /// Whether a turn is currently in flight ([submitted], [streaming], or
  /// [executingTools]) — i.e. the model or its tools are still working.
  bool get isBusy =>
      this == submitted || this == streaming || this == executingTools;
}
