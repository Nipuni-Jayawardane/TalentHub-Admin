class ConfigDev {
  // For local development - you can set up a proxy server or use a local backend
  static const String localBackendBaseUrl = "http://localhost:3000/api"; // Local proxy
  
  // Original production URL (has CORS issues on web)
  static const String prodBackendBaseUrl = "https://talenthub.slt.lk/api";
  
  // Use production URL for now (works on mobile/desktop)
  static const String backendBaseUrl = "https://talenthub.slt.lk/api";
}