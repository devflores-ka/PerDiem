class SupabaseOptions {
  final String url;
  final String anonKey;

  SupabaseOptions({
    required this.url,
    required this.anonKey,
  });
}

final SupabaseOptions supabaseOptions = SupabaseOptions(
  url: 'https://obebqaertspxottkblzm.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9iZWJxYWVydHNweG90dGtibHptIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQwNTAzMzgsImV4cCI6MjA1OTYyNjMzOH0.JneFovZP7c7d0qzVNRRghTzR5mQFXca_DNaum08NqW8',
);
