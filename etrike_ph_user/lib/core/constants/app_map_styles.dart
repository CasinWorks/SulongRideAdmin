/// Google Maps JSON styling for the eco dark theme.
///
/// Default map labels use a heavy typeface; bright fill colors make them look
/// bold and hard to read on dark terrain. Muted fills plus a dark stroke keep
/// place names legible without shouting over the ride UI.
abstract final class AppMapStyles {
  static const ecoDark = r'''
[
  {"elementType":"geometry","stylers":[{"color":"#08170F"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8A9B8E"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0B2114"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#6E7F72"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#6E7F72"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#143120"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#A3B5A8"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1C4E34"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#132535"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#122E1F"}]}
]
''';

  /// Calmer map while a ride is active — hides POI names that clutter the view.
  static const ecoTrip = r'''
[
  {"elementType":"geometry","stylers":[{"color":"#08170F"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#8A9B8E"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0B2114"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#6E7F72"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#6E7F72"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#143120"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#A3B5A8"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#1C4E34"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#132535"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#122E1F"}]}
]
''';
}
