class SupabaseOptions {
  final String url;
  final String anonKey;

  SupabaseOptions({
    required this.url,
    required this.anonKey,
  });
}

final SupabaseOptions supabaseOptions = SupabaseOptions(
  url: 'https://aggojuchghgtthbfuglz.supabase.co',
  anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFnZ29qdWNoZ2hndHRoYmZ1Z2x6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIzNDU0MDEsImV4cCI6MjA1NzkyMTQwMX0.ar4qtIa3aOHCQ0_HE-N-Gz_g1XtuCK1Ke8DouXTTSEE',
);
