import 'dart:async';
import 'dart:math';

class SmartWatchSimulatorService {
  SmartWatchSimulatorService._();
  static final instance = SmartWatchSimulatorService._();

  final _random = Random();
  Timer? _timer;
  bool _connected = false;

  int heartRate = 75;
  double temperature = 36.5;
  String bloodPressure = '116/72';

  final StreamController<void> _streamController =
  StreamController<void>.broadcast();

  Stream<void> get vitalsStream => _streamController.stream;
  bool get isConnected => _connected;

  void connect() {
    if (_connected) return;

    _connected = true;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      heartRate = 70 + _random.nextInt(15);
      temperature = 36 + _random.nextDouble();
      bloodPressure =
      '${110 + _random.nextInt(10)}/${70 + _random.nextInt(10)}';

      _streamController.add(null);
    });
  }
}
