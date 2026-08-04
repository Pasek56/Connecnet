import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://cjxgqskachxnvnsmwiaa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqeGdxc2thY2h4bnZuc213aWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzOTIzODYsImV4cCI6MjA5Njk2ODM4Nn0.RiKdksaNwRHBO07dx57DSUM2h_3MU9Z2q7mswHnR4lw',
  );

  print('Testing connection to Supabase...');
  try {
    final res = await supabase.schema('perfiles').from('perfil_unificado').select().limit(1);
    print('Connection successful. Sample query returned ${res.length} rows.');
  } catch (e) {
    print('Connection query failed: $e');
  }
}







