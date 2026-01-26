class SupabaseConfig {
  // Your Supabase project details
  static const String projectUrl = 'https://cbdirfispvyknwmfhwln.supabase.co';
  static const String anonKey = 'YOUR_SUPABASE_ANON_KEY'; // Get from Supabase dashboard
  
  // API Endpoints
  static const String healthApi = '$projectUrl/functions/v1/health';
  static const String personApi = '$projectUrl/functions/v1/person';
  static const String subscriptionApi = '$projectUrl/functions/v1/subscription';
  static const String applinkApi = '$projectUrl/functions/v1/applink';
}
