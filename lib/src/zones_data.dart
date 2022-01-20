class Zone {
  final double start;
  final double end;
  final double high;
  final double low;
  final String type;

  Zone(this.start, this.end, this.high, this.low, this.type);
}

List<Zone> zonesFromJSON(dynamic json) {
  if (json is! List) throw Exception('err parsing json: root is not list');
  return json.map((dynamic row) {
    return Zone(
      row['start'] * 1.0,
      row['end'] * 1000.0,
      row['high'] * 1.0,
      row['low'] * 1.0,
      row['type'],
    );
  }).toList();
}
