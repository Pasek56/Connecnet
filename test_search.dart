import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://cjxgqskachxnvnsmwiaa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqeGdxc2thY2h4bnZuc213aWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzOTIzODYsImV4cCI6MjA5Njk2ODM4Nn0.RiKdksaNwRHBO07dx57DSUM2h_3MU9Z2q7mswHnR4lw',
  );

  try {
    print('Testing query on nombres...');
    final res1 = await supabase
        .schema('perfiles')
        .from('perfil_unificado')
        .select()
        .ilike('nombres', '%a%')
        .limit(2);
    print('Result 1: $res1');
  } catch (e) {
    print('Error on nombres: $e');
  }

  try {
    print('Testing query on nombres_prof...');
    final res2 = await supabase
        .schema('perfiles')
        .from('perfil_unificado')
        .select()
        .ilike('nombres_prof', '%a%')
        .limit(2);
    print('Result 2: $res2');
  } catch (e) {
    print('Error on nombres_prof: $e');
  }
}
