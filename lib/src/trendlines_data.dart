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
      row['end'].toDouble(),
      row['start'].toDouble(),
      row['still_active'],
      row['touch_points'] != null
          ? row['touch_points'].map<TouchPoint>((dynamic raw) {
              return TouchPoint(
                raw['distance'].toDouble(),
                raw['idx'].toDouble(),
                raw['value'].toDouble(),
              );
            }).toList()
          : [],
      row['type'],
      row['y1'].toDouble(),
      row['y2'].toDouble(),
    );
  }).toList();
}
