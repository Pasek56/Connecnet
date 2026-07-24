# Resumen de Cambios en el Código

En esta sesión, realizamos cambios en el código de Flutter para solucionar los problemas de obtención de datos (relacionados con los `JOIN` entre distintos esquemas de Supabase). A continuación se detalla lo que se modificó, excluyendo las consultas SQL.

## Archivos Modificados

### `lib/screens/dashboard_screen.dart`

Se modificó la forma en la que se obtienen los encargos y los comentarios para evitar el uso de `.select('*, sender:sender_profile_id(*)')`. Dado que PostgREST/Supabase no soporta `JOIN` directos entre distintos esquemas (como `publicaciones` y `perfiles`) de forma predeterminada sin Vistas SQL, reestructuramos el código para realizar la unión ("merge") de datos manualmente en Dart.

#### 1. Método `_fetchEncargos`
**Antes:**
Se intentaba hacer el join directamente en la base de datos pidiendo la relación `sender_profile_id`.
```dart
final response = await _supabase
    .schema('publicaciones')
    .from('encargo')
    .select('*, sender:sender_profile_id(*), comentarios:comentarios(count)')
    .order('id_enc', ascending: false);

setState(() {
  _encargos = List<Map<String, dynamic>>.from(response);
});
```

**Después:**
Ahora se obtienen los encargos primero. Luego, se extraen todos los `sender_profile_id` y se hace una única petición adicional a la tabla `perfil_unificado` para descargar los perfiles correspondientes. Finalmente, se inyectan dentro de los datos de cada encargo.
```dart
final response = await _supabase
    .schema('publicaciones')
    .from('encargo')
    .select('*, comentarios:comentarios(count)')
    .order('id_enc', ascending: false);

List<Map<String, dynamic>> encargos = List<Map<String, dynamic>>.from(response);

// Extraer IDs únicos de remitentes
final senderIds = encargos
    .map((e) => e['sender_profile_id'])
    .where((id) => id != null)
    .toSet()
    .toList();

if (senderIds.isNotEmpty) {
  // Buscar perfiles
  final profilesResponse = await _supabase
      .schema('perfiles')
      .from('perfil_unificado')
      .select()
      .filter('id', 'in', senderIds);
      
  final profiles = List<Map<String, dynamic>>.from(profilesResponse);
  final profileMap = {for (var p in profiles) p['id']: p};

  // Asociar perfiles a los encargos
  for (var encargo in encargos) {
    final senderId = encargo['sender_profile_id'];
    if (senderId != null) {
      encargo['sender'] = profileMap[senderId];
    }
  }
}

setState(() {
  _encargos = encargos;
});
```

#### 2. Método `_fetchComments`
**Antes:**
```dart
final response = await _supabase
    .schema('publicaciones')
    .from('comentarios')
    .select('*, sender:sender_profile_id(*)')
    .eq('encargo_id', widget.encargo['id_enc'])
    .order('id_coment', ascending: true);

setState(() {
  _comments = List<Map<String, dynamic>>.from(response);
  _isLoadingComments = false;
});
```

**Después:**
Se aplicó exactamente la misma lógica de "Data Loader" para evitar el join entre esquemas.
```dart
final response = await _supabase
    .schema('publicaciones')
    .from('comentarios')
    .select('*')
    .eq('encargo_id', widget.encargo['id_enc'])
    .order('id_coment', ascending: true);

List<Map<String, dynamic>> comments = List<Map<String, dynamic>>.from(response);

// Extraer IDs únicos
final senderIds = comments
    .map((c) => c['sender_profile_id'])
    .where((id) => id != null)
    .toSet()
    .toList();

if (senderIds.isNotEmpty) {
  final profilesResponse = await _supabase
      .schema('perfiles')
      .from('perfil_unificado')
      .select()
      .filter('id', 'in', senderIds);
      
  final profiles = List<Map<String, dynamic>>.from(profilesResponse);
  final profileMap = {for (var p in profiles) p['id']: p};

  for (var c in comments) {
    final senderId = c['sender_profile_id'];
    if (senderId != null) {
      c['sender'] = profileMap[senderId];
    }
  }
}

setState(() {
  _comments = comments;
  _isLoadingComments = false;
});
```

---

> [!TIP]
> **Ventaja de este patrón:** Este enfoque (también conocido como *Data Loader pattern*) no solo evita el problema con esquemas cruzados de PostgREST, sino que también es muy eficiente, ya que agrupa las peticiones de los perfiles en una sola consulta a la base de datos (mediante `filter('id', 'in', senderIds)`), evitando hacer cientos de consultas repetidas.
