# Perfiles Personalizados Implementados

Se ha implementado el sistema dinámico de perfiles en base al esquema `perfil_unificado` de Supabase, adaptando la interfaz según el tipo de usuario y expandiendo las capacidades de edición, siguiendo tus indicaciones de omitir el banner.

## Cambios Realizados

- **Conexión de Datos Dinámicos**: En [profile_screen.dart](file:///c:/Users/migue/OneDrive/Documentos/GitHub/Connecnet/lib/screens/profile_screen.dart), el nombre, el usuario (`@handle`), la foto de perfil y la biografía ahora se construyen usando los datos reales obtenidos desde la base de datos a través de `_fetchProfile`.
- **Biografía Contextual**:
  - Si el usuario es **Estudiante**, su biografía mostrará el semestre (Ej: *"Estudiante de 5 Semestre."*).
  - Si el usuario es **Profesional**, su biografía mostrará su título (Ej: *"Ingeniero de Software"*).
- **Formulario de Edición Dinámico**:
  - Al dar clic en "Editar perfil", ahora aparece un diálogo rediseñado.
  - Permite editar los **Nombres** y **Apellidos**.
  - Permite seleccionar el **Tipo de Perfil** (Estudiante o Profesional) mediante un menú desplegable.
  - Dependiendo del tipo seleccionado, muestra un campo extra: *"Semestre"* (para estudiantes) o *"Título/Profesión"* (para profesionales).
- **Actualización a la Base de Datos**: Al darle a guardar, la aplicación manda un *update* a `perfil_unificado` en Supabase y refresca la información de la pantalla al instante.

## Qué probar
1. Abre tu perfil en la aplicación.
2. Da clic en "Editar perfil" e introduce un nuevo nombre y selecciona que eres "Estudiante" en semestre "3". Guarda los cambios.
3. Vuelve a abrir "Editar perfil", cambia tu rol a "Profesional", y pon un Título.
4. Observa cómo cambia la biografía bajo tu nombre en tiempo real.

> [!NOTE]  
> Ten en cuenta que si actualizas la foto de perfil en el diálogo, se mostrará localmente en la vista, pero para guardarla permanentemente en internet necesitaremos tener configurado los *Storage Buckets* en tu servidor de Supabase en un futuro.
