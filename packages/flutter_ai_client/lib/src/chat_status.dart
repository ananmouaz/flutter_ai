/// The lifecycle state of a chat turn driven by a controller.
enum ChatStatus {
  /// No request is in flight.
  idle,

  /// A request has been sent but no events have arrived yet.
  submitted,

  /// Events are actively streaming in.
  streaming,

  /// The last request failed.
  error;

  /// Whether a request is currently in flight ([submitted] or [streaming]).
  bool get isBusy => this == submitted || this == streaming;
}
