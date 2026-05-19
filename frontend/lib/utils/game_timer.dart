import 'dart:async';

class GameTimer {
  Timer? _timer;

  void start({
    required int seconds,
    required Function(int) onTick,
    required Function() onEnd,
  }) {
    int timeLeft = seconds;

    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timeLeft == 0) {
        t.cancel();
        onEnd();
      } else {
        timeLeft--;
        onTick(timeLeft);
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
}