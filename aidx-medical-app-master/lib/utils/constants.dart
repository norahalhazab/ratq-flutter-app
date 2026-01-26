class AppConstants {
  // API Keys
  static const String newsApiKey = "YOUR_NEWS_API_KEY";
  static const String geminiApiKey = "YOUR_GEMINI_API_KEY";
  static const String groqApiKey = "YOUR_GROQ_API_KEY";
  
  // Development mode flag
  static const bool isDevelopmentMode = false;
  
  // Shared Preferences Keys
  static const String prefThemeMode = "theme_mode";
  static const String prefAutoSos = "auto_sos";
  static const String prefCountry = "news_country";
  static const String prefMood = "user_mood";
  
  // BLE Service UUIDs
  static const String heartRateServiceUuid = "0000180d-0000-1000-8000-00805f9b34fb";
  static const String heartRateMeasurementCharUuid = "00002a37-0000-1000-8000-00805f9b34fb";
  static const String pulseOximeterServiceUuid = "00001822-0000-1000-8000-00805f9b34fb";
  static const String spo2MeasurementCharUuid = "00002a5f-0000-1000-8000-00805f9b34fb";
  // Blood Pressure (standard)
  static const String bloodPressureServiceUuid = "00001810-0000-1000-8000-00805f9b34fb"; // Blood Pressure Service
  static const String bloodPressureMeasurementCharUuid = "00002a35-0000-1000-8000-00805f9b34fb"; // Blood Pressure Measurement
  // Proprietary placeholders (replace after identifying via BLE scanner like nRF Connect)
  static const String proprietarySpO2ServiceUuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  static const String proprietarySpO2CharUuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  static const String proprietaryBpServiceUuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  static const String proprietaryBpCharUuid = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
  
  // Emergency SOS
  static const int sosMonitoringIntervalMs = 1000; // Check vitals every second
  static const int sosAbnormalDurationMs = 30000; // 30 seconds of abnormal vitals before alert
  static const int hrThresholdHigh = 180; // BPM
  static const int spo2ThresholdLow = 85; // Percent
  
  // Default emergency numbers by country code
  static const Map<String, String> emergencyNumbers = {
    "US": "911",
    "CA": "911",
    "GB": "999",
    "AU": "000",
    "EU": "112",
    "IN": "112"
  };
  static const String defaultEmergencyNumber = "112";
  
  // Routes
  static const String routeLogin = "/login";
  static const String routeDashboard = "/dashboard";
  static const String routeSymptom = "/symptom";
  static const String routeChat = "/chat";
  static const String routeDrug = "/drug";
  static const String routeHospital = "/hospital";
  static const String routePharmacy = "/pharmacy";
  static const String routeProfessionalsPharmacy = "/professionals-pharmacy";
  static const String routeWearable = "/wearable";
  static const String routeReminder = "/reminder";
  static const String routeTimeline = "/timeline";
  static const String routeSos = "/sos";
  static const String routeProfile = "/profile";
  static const String routeSymptomAI = "/symptom_ai";
  static const String routeNewsDetail = "/news_detail";
  static const String routeBloodDonation = "/blood-donation";
  static const String routeCases = '/cases';
  static const String routeVitals = '/vitals';
  static const String routeHealthId = '/health-id';
  static const String routePermissions = '/permissions';
  static const String routeAiVision = '/ai-vision';
  static const String routeAiVideoCall = '/ai-video-call';
  static const String routeFirstAid = '/first-aid';
  static const String routeDoctorSearch = '/doctor-search';
  static const String routePharmacySearch = '/pharmacy-search';
  static const String routePremium = '/premium';

  // Legal/Privacy
  static const String healthDisclaimer =
      "This app displays smartwatch vitals for wellness only and is not a substitute for professional medical advice.";
  
  // Elderly Features Routes

  static const String routeHealthHabits = '/health_habits';
  static const String routeSleepFallDetection = '/sleep_fall_detection';

  static const String routeCommunitySupport = '/community_support';


  // Telegram SOS
  // TODO: Replace with your actual bot token and chat ID
  static const String telegramBotToken = "YOUR_TELEGRAM_BOT_TOKEN";
  static const String telegramChatId = "-1002835748169"; // aidx super-group

  // Extra chat IDs (e.g., private DMs) that should also receive SOS
  static const List<String> extraTelegramChatIds = [
    "7921789120", // Alvee personal DM
  ];
} 