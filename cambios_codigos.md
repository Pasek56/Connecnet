# Registro de Cambios en Código (Connecnet)

Este documento registra los últimos cambios implementados en la aplicación.

## 1. Modificaciones en el Dashboard (`lib/screens/dashboard_screen.dart`)
- **Eliminación de Tabs:** Se eliminó el `DefaultTabController` y las pestañas (Publicaciones / Noticias). La pantalla principal ahora muestra únicamente el muro principal de "Publicaciones" de manera limpia.
- **Rediseño del Botón de Noticias:** Se modificó el `FloatingActionButton` de la esquina inferior derecha. Ahora utiliza una `Column` que contiene dos botones:
  - **Botón Superior (Noticias):** Abre la interfaz de noticias (`NewsScreen`) en forma de una ventana modal emergente (Dialog) centrada en la pantalla con esquinas redondeadas, sin necesidad de navegar a otra pestaña.
  - **Botón Inferior (Perfil):** Mantiene la funcionalidad de navegar a la pantalla de perfil (`ProfileScreen`).

## 2. Modificaciones en el Perfil (`lib/screens/profile_screen.dart`)
- **Guardado de Foto de Perfil (Fix):** Se corrigió el error donde la imagen seleccionada por el usuario no se guardaba. En la función `_showEditProfileDialog`, se agregó el campo `pfp: selectedImagePath` al mapa de actualizaciones (`updates`) enviado a Supabase, permitiendo que la foto quede persistida en la base de datos.
- **Visualización de Posts del Usuario:**
  - Se modificó la lista `_tweets` (quitando la constante `final`) para permitir actualizaciones dinámicas.
  - Se creó el método `_fetchUserPosts()`, el cual consulta la tabla `encargo` filtrando por `sender_profile_id` igual al ID del perfil del usuario actual.
  - Se integró la llamada `await _fetchUserPosts()` dentro del método principal `_fetchProfile()`. Como resultado, la pestaña "Posts" dentro del perfil del usuario ahora muestra todas las publicaciones reales que este haya hecho en la plataforma, mapeadas al diseño de tweets existente.
