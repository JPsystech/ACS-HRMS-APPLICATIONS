import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'punch_session.dart';

/// UI-only controller for the current punch session (in or out).
/// [state] is null when no session is active; otherwise holds [PunchSession].
class PunchSessionController extends StateNotifier<PunchSession?> {
  PunchSessionController() : super(null);

  void startPunchIn() {
    state = PunchSession(
      isPunchIn: true,
      startedAt: DateTime.now(),
    );
  }

  void startPunchOut() {
    state = PunchSession(
      isPunchIn: false,
      startedAt: DateTime.now(),
    );
  }

  void setFaceCaptured(String pathOrToken) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(faceImagePath: pathOrToken);
  }

  void setLocation(double lat, double lng, double accuracy) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      locationCapturedAt: DateTime.now(),
    );
  }

  void reset() {
    state = null;
  }
}
