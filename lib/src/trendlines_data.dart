class Trendline {
  final double end;
  final double start;
  final bool stillActive;
  final List<TouchPoint> touchPoints;
  final String type;
  final double y1;
  final double y2;
  Trendline(this.end, this.start, this.stillActive, this.touchPoints, this.type, this.y1, this.y2);
}

class TouchPoint {
  final double distance;
  final double idx;
  final double value;

  TouchPoint(this.distance, this.idx, this.value);
}

List<Trendline> trendlinesFromJSON(dynamic json) {
  if (json is! List) throw Exception('err parsing json: root is not list');
  return json.map((row) {
    // debugPrint(row.toString());
    return Trendline(
      row['end'] * 1.0,
      row['start'] * 1.0,
      row['still_active'],
      row['touch_points'] != null
          ? row['touch_points'].map<TouchPoint>((dynamic raw) {
              return TouchPoint(
                raw['distance'] * 1.0,
                raw['idx'] * 1.0,
                raw['value'] * 1.0,
              );
            }).toList()
          : [],
      row['type'],
      row['y1'] * 1.0,
      row['y2'] * 1.0,
    );
  }).toList();
}
