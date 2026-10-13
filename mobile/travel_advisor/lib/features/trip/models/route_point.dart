
class RoutePoint {
  final String name;
  final double latitude;
  final double longitude;

  const RoutePoint({
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  static const List<RoutePoint> all = [
    RoutePoint(
      name: 'Mumbai / Sion',
      latitude: 19.04650,
      longitude: 72.86330,
    ),
    RoutePoint(
      name: 'Panvel',
      latitude: 18.98878,
      longitude: 73.11013,
    ),
    RoutePoint(
      name: 'Khalapur',
      latitude: 18.81670,
      longitude: 73.26670,
    ),
    RoutePoint(
      name: 'Khopoli',
      latitude: 18.78770,
      longitude: 73.34380,
    ),
    RoutePoint(
      name: 'Khandala',
      latitude: 18.77001,
      longitude: 73.38300,
    ),
    RoutePoint(
      name: 'Lonavala',
      latitude: 18.75460,
      longitude: 73.40620,
    ),
    RoutePoint(
      name: 'Kamshet',
      latitude: 18.76290,
      longitude: 73.55760,
    ),
    RoutePoint(
      name: 'Pune',
      latitude: 18.52050,
      longitude: 73.85650,
    ),
  ];
}