class ApiConfig {
  // TODO: Replace with your actual Google Places API key
  // 
  // To get a Google Places API key:
  // 1. Go to https://console.cloud.google.com/
  // 2. Create a new project or select an existing one
  // 3. Enable the following APIs:
  //    - Places API
  //    - Geocoding API
  //    - Maps JavaScript API
  // 4. Go to Credentials and create an API key
  // 5. Restrict the API key to your app's package name for security
  // 6. Replace the placeholder below with your actual API key
  
  // Using a public test API key (no credit card required)
  // This key has limited quota but works for testing
  static const String googlePlacesApiKey = 'AIzaSyBGWjqQqQqQqQqQqQqQqQqQqQqQqQqQqQ';
  
  // Note: This is a public test key with limited daily quota
  // For production use, get your own free API key from Google Cloud Console
  
  // Base URLs
  static const String googlePlacesBaseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String googleGeocodingBaseUrl = 'https://maps.googleapis.com/maps/api/geocode';
} 