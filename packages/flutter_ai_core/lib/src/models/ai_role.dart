/// The author of a message in a conversation.
enum AiRole {
  /// System or developer instructions that condition the model's behavior.
  system('system'),

  /// A human end user.
  user('user'),

  /// The model.
  assistant('assistant'),

  /// Output produced by a tool and fed back to the model.
  tool('tool');

  const AiRole(this.wireName);

  /// The stable string used on the wire and in JSON.
  ///
  /// Decoupled from `Enum.name` so renaming a Dart identifier never silently
  /// changes the serialized form.
  final String wireName;

  /// Parses a [wireName] into its [AiRole].
  ///
  /// Throws a [FormatException] if [value] does not match a known role.
  static AiRole fromJson(String value) {
    for (final role in values) {
      if (role.wireName == value) return role;
    }
    throw FormatException('Unknown AiRole: "$value"');
  }

  /// The wire representation of this role.
  String toJson() => wireName;
}
