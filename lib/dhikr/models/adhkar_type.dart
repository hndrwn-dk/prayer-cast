enum AdhkarType {
  morning,
  evening;

  static AdhkarType fromString(String value) {
    switch (value) {
      case 'morning':
        return AdhkarType.morning;
      case 'evening':
        return AdhkarType.evening;
      default:
        throw ArgumentError('Invalid AdhkarType: $value');
    }
  }
}
