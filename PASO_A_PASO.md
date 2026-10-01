# Integrador de Bases de Datos – Biblioteca

Motor usado: **PostgreSQL** (PL/pgSQL). Todo lo que se crea está en `01_estructura_datos_y_logica.sql`.

## Cómo probarlo
1. Ir probando los comandos de abajo **en orden**, de a uno: algunos resultados dependen de los anteriores (por ejemplo, el préstamo 7 se crea en el Paso 4 y se borra en el Bonus).
2. Las pruebas marcadas con ⚠️ **DA ERROR SÍ O SÍ** son las que tienen que fallar: el error es el resultado correcto, porque el trigger o el procedimiento está bloqueando la operación. Hay que ejecutarlas de a una, porque si se corren juntas con otras, el error frena todo lo que viene después.

## Paso 1 – Tablas y datos
Creé `libros`, `socios`, `prestamos` (con claves foráneas a socios y libros) y `auditoria_prestamos`, y cargué los datos de prueba (5 libros, 5 socios, 6 préstamos). Los préstamos de ejemplo se cargan **antes** de crear los triggers, así que no modifican el stock.

## Paso 2 – Funciones

**`cantidad_prestamos_socio(p_id_socio)`**: cuenta con `COUNT(*)` los préstamos del socio.
- Prueba: `SELECT cantidad_prestamos_socio(1);` → **2**

**`libro_disponible(p_id_libro)`**: devuelve `TRUE` si el stock es mayor a 0, `FALSE` si no (también `FALSE` si el libro no existe).
- Prueba: `SELECT libro_disponible(1);` → **TRUE** (stock 3)
- Prueba: `SELECT libro_disponible(5);` → **FALSE** (stock 0)

## Paso 3 – Procedimientos

**`registrar_socio(p_nombre, p_apellido, p_email)`**: inserta un socio con `activo = TRUE`.
- Prueba: `CALL registrar_socio('Carlos', 'Gómez', 'carlos@mail.com');` y luego `SELECT * FROM socios;` → aparece el socio 6, Carlos Gómez, activo.

**`devolver_libro(p_id_prestamo)`**:
- Si el préstamo no existe → `RAISE EXCEPTION`.
- Si ya tiene `fecha_devolucion` → `RAISE EXCEPTION` ("ya fue devuelto").
- Si no, pone `fecha_devolucion = CURRENT_DATE` y suma 1 al stock del libro.
- Prueba: `CALL devolver_libro(2);` → el préstamo 2 queda con la fecha de hoy y el stock del libro 2 pasa de **2 a 3** (se puede verificar con `SELECT * FROM prestamos;` y `SELECT * FROM libros;`).
- ⚠️ **DA ERROR SÍ O SÍ:** `CALL devolver_libro(1);` → **ERROR: El préstamo 1 ya fue devuelto el 2026-09-10** (el préstamo 1 ya tenía fecha de devolución).

## Paso 4 – Triggers

**BEFORE INSERT en `prestamos`** (`trg_validar_prestamo`): antes de guardar el préstamo revisa:
- que el socio exista y esté activo;
- que el libro tenga stock (reutiliza `libro_disponible`).

Si algo falla, lanza `RAISE EXCEPTION` con un mensaje claro y el préstamo no se guarda. Si todo está bien termina con `RETURN NEW` (sin eso el INSERT se cancelaría sin avisar).
- ⚠️ **DA ERROR SÍ O SÍ:** `INSERT INTO prestamos (id_socio, id_libro) VALUES (4, 1);` → **ERROR: No se puede registrar el préstamo: el socio 4 no está activo** (el socio 4 es Mateo, inactivo).
- ⚠️ **DA ERROR SÍ O SÍ:** `INSERT INTO prestamos (id_socio, id_libro) VALUES (1, 5);` → **ERROR: No se puede registrar el préstamo: el libro 5 no tiene stock** (el libro 5 tiene stock 0).

**AFTER INSERT en `prestamos`** (`trg_descontar_stock`): después de guardar el préstamo, resta 1 al stock del libro.
- Prueba (esta **no** da error): `SELECT stock FROM libros WHERE id_libro = 4;` → **4**. Luego `INSERT INTO prestamos (id_socio, id_libro) VALUES (2, 4);` y volver a consultar → **3**. El préstamo queda registrado con id 7.

## Bonus – Trigger de auditoría
**AFTER DELETE en `prestamos`** (`trg_auditar_borrado_prestamo`): guarda en `auditoria_prestamos` la acción `'DELETE'` y el id del préstamo borrado. Termina con `RETURN OLD`.
- Prueba (no da error): `DELETE FROM prestamos WHERE id_prestamo = 7;` (el que se creó en el Paso 4) y luego `SELECT * FROM auditoria_prestamos;` → una fila con `DELETE` y `id_prestamo = 7`.

## Resumen: qué da error y qué no
| Comando | ¿Da error? |
|---|---|
| `CALL devolver_libro(1);` | ⚠️ Sí, siempre (ya devuelto) |
| `INSERT ... VALUES (4, 1);` | ⚠️ Sí, siempre (socio inactivo) |
| `INSERT ... VALUES (1, 5);` | ⚠️ Sí, siempre (libro sin stock) |
| Todo el resto | No |
