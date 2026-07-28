List<Object?> readObjectList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List<Object?>) {
    return value;
  }

  throw FormatException('Missing or invalid "$key" list.');
}

Map<String, Object?> readObject(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is Map<String, Object?>) {
    return value;
  }

  throw FormatException('Missing or invalid "$key" object.');
}

String readString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }

  throw FormatException('Missing or invalid "$key" string.');
}

String? readOptionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }

  throw FormatException('Invalid "$key" string.');
}

bool readBool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }

  throw FormatException('Missing or invalid "$key" boolean.');
}

int readInt(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }

  throw FormatException('Missing or invalid "$key" integer.');
}

List<String> readStringList(Map<String, Object?> json, String key) {
  return readObjectList(json, key)
      .map((value) {
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }

        throw FormatException('Invalid value in "$key" list.');
      })
      .toList(growable: false);
}
