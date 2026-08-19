import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  // Desactivar overrides de prueba de Flutter que bloquean HTTP
  HttpOverrides.global = MyHttpOverrides();

  test('Test Supabase Connection with HTTP enabled', () async {
    print('Inicializando mocks...');
    SharedPreferences.setMockInitialValues({});

    print('Inicializando Supabase...');
    try {
      await Supabase.initialize(
        url: 'https://cjxgqskachxnvnsmwiaa.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNqeGdxc2thY2h4bnZuc213aWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEzOTIzODYsImV4cCI6MjA5Njk2ODM4Nn0.RiKdksaNwRHBO07dx57DSUM2h_3MU9Z2q7mswHnR4lw',
      );
    } catch (e) {
      print('Error al inicializar: $e');
    }

    final client = Supabase.instance.client;

    try {
      print('Consultando las primeras 5 notificaciones con schema "notificaciones"...');
      final res = await client.schema('notificaciones').from('notificaciones').select().limit(5);
      print('Éxito. Encontrados: ${res.length} registros.');
      for (var i = 0; i < res.length; i++) {
        final row = res[i];
        print('Fila $i:');
        row.forEach((key, value) {
          print('  $key: $value (${value.runtimeType})');
        });
      }
    } catch (e) {
      print('Error al consultar notificaciones con schema "notificaciones": $e');
    }

    try {
      print('Consultando perfil_unificado...');
      final res = await client.schema('perfiles').from('perfil_unificado').select().limit(2);
      print('Éxito perfiles. Encontrados: ${res.length} registros.');
      for (var i = 0; i < res.length; i++) {
        final row = res[i];
        print('Perfil $i:');
        row.forEach((key, value) {
          print('  $key: $value (${value.runtimeType})');
        });
      }
    } catch (e) {
      print('Error perfiles: $e');
    }
  });
}
