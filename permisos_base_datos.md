# Configuración de Permisos en Supabase (PostgreSQL)

Cuando se utilizan esquemas personalizados (schemas que no son el predeterminado `public`), PostgREST (la API de Supabase) bloquea el acceso por defecto por motivos de seguridad. Esto genera errores del tipo `permission denied for schema`, con código de error `42501` o `403`.

Para que los usuarios que se conectan desde la aplicación de Flutter (con los roles `anon` y `authenticated`) puedan leer, escribir e insertar datos, se deben ejecutar una serie de permisos (GRANTS) desde el **SQL Editor** del panel de Supabase.

A continuación, se documentan los comandos SQL necesarios para solucionar todos los errores encontrados durante la integración de los esquemas `publicaciones` y `perfiles`.

---

## 1. Permisos para el Esquema `publicaciones`

El esquema de publicaciones almacena las tablas de `encargo` y `comentarios`. Necesitamos que los usuarios logueados (y los no logueados si corresponde) puedan consultar esta información.

```sql
-- 1. Dar permiso de "uso" del esquema a la API
GRANT USAGE ON SCHEMA publicaciones TO anon, authenticated;

-- 2. Permitir leer (SELECT) todas las tablas del esquema
GRANT SELECT ON ALL TABLES IN SCHEMA publicaciones TO anon, authenticated;

-- (Opcional) Si en la app permites publicar encargos o hacer comentarios:
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA publicaciones TO authenticated;
```

---

## 2. Permisos para el Esquema `perfiles`

El esquema de perfiles almacena la tabla `perfil_unificado`. A diferencia de las publicaciones, aquí la aplicación necesita tanto leer los perfiles (para ver quién publicó algo) como **insertar o actualizar** los datos cuando un usuario inicia sesión por primera vez y configura su perfil.

```sql
-- 1. Dar permiso de "uso" del esquema a la API
GRANT USAGE ON SCHEMA perfiles TO anon, authenticated;

-- 2. Permitir leer (SELECT) todas las tablas del esquema
GRANT SELECT ON ALL TABLES IN SCHEMA perfiles TO anon, authenticated;

-- 3. Permitir escribir y modificar (INSERT, UPDATE, DELETE) en las tablas
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA perfiles TO authenticated;
```

---

## 3. Permisos de Secuencias (IDs Auto-incrementales)

> [!WARNING]
> **El problema de las Secuencias**
> Aunque le des a un usuario permisos de `INSERT` sobre una tabla, si la tabla utiliza una columna `id` auto-incremental (como `SERIAL`), PostgreSQL intentará leer el próximo número de la "secuencia" interna (ej. `perfil_unificado_id_seq`). Si la secuencia no tiene permisos, el `INSERT` fallará.

Para permitir que los usuarios puedan crear nuevos registros (como crear un perfil nuevo), debes habilitar el acceso a las secuencias para ambos esquemas.

```sql
-- 1. Permitir el uso de las secuencias en el esquema de perfiles
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA perfiles TO anon, authenticated;

-- 2. Permitir el uso de las secuencias en el esquema de publicaciones
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA publicaciones TO anon, authenticated;
```

---

## Resumen Final: Script Completo

Si necesitas aplicar todos los permisos en una nueva base de datos o restaurarlos, puedes ejecutar el siguiente script completo en el SQL Editor de Supabase:

```sql
-- ========= PUBLICACIONES =========
GRANT USAGE ON SCHEMA publicaciones TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA publicaciones TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA publicaciones TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA publicaciones TO anon, authenticated;

-- ========= PERFILES =========
GRANT USAGE ON SCHEMA perfiles TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA perfiles TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA perfiles TO authenticated;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA perfiles TO anon, authenticated;
```
