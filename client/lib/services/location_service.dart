import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import './consent_service.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    // Verificar consentimento LGPD
    final hasConsent = await ConsentService.hasLocationConsent();
    if (!hasConsent) {
      return null;
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition();
  }

  static double calculateDistance(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }
}
