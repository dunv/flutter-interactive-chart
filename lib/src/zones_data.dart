class Zone {
  final int start;
  final int end;
  final double high;
  final double low;
  final String type;

  Zone(this.start, this.end, this.high, this.low, this.type);
}

List<Zone> zonesFromJSON(dynamic json) {
  if (json is! List) throw Exception('err parsing json: root is not list');
  return json.map((dynamic row) {
    // debugPrint(row.toString());
    return Zone(
      row['start'],
      row['end'] * 1000,
      row['high'],
      row['low'],
      row['type'],
    );
  }).toList();
}
