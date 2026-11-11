/// Parser textual KeyValues (VDF/ACF): preserva hierarquia, strings escapadas,
/// comentários e valores sem aspas. As chaves da Valve não diferenciam caixa.
Map<String, dynamic> parseValveKeyValues(String input) {
  final tokens = <String>[];
  var cursor = 0;
  while (cursor < input.length) {
    final c = input[cursor];
    if (c.trim().isEmpty || c == '\ufeff') {
      cursor++;
      continue;
    }
    if (c == '/' && cursor + 1 < input.length && input[cursor + 1] == '/') {
      while (cursor < input.length && input[cursor] != '\n') {
        cursor++;
      }
      continue;
    }
    if (c == '{' || c == '}') {
      tokens.add(c);
      cursor++;
      continue;
    }
    if (c == '"') {
      cursor++;
      final value = StringBuffer();
      while (cursor < input.length) {
        final ch = input[cursor++];
        if (ch == '"') break;
        if (ch == '\\' &&
            cursor < input.length &&
            (input[cursor] == '\\' || input[cursor] == '"')) {
          value.write(input[cursor++]);
        } else {
          value.write(ch);
        }
      }
      tokens.add(value.toString());
    } else {
      final start = cursor;
      while (cursor < input.length &&
          input[cursor].trim().isNotEmpty &&
          input[cursor] != '{' &&
          input[cursor] != '}') {
        cursor++;
      }
      tokens.add(input.substring(start, cursor));
    }
  }
  var index = 0;
  Map<String, dynamic> object() {
    final result = <String, dynamic>{};
    while (index < tokens.length) {
      final key = tokens[index++];
      if (key == '}') break;
      if (index >= tokens.length) break;
      final value = tokens[index++];
      if (value == '}') break;
      result[key.toLowerCase()] = value == '{' ? object() : value;
    }
    return result;
  }

  return object();
}
