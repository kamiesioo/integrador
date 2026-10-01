# Integrador de Bases de Datos – Biblioteca

Motor usado: **PostgreSQL** (PL/pgSQL). Archivos: `01_estructura_datos_y_logica.sql` (todo lo que se crea) y `02_pruebas.sql` (las pruebas).

## Cómo probarlo
1. Crear una base vacía y ejecutar completo `01_estructura_datos_y_logica.sql` (se puede re-ejecutar, borra y recrea todo).
2. Ejecutar `02_pruebas.sql` en orden. Los resultados esperados están en cada comentario `-- Esperado`.
3. Las pruebas que **deben dar error** están al final de `02_pruebas.sql` y se ejecutan con una función de ayuda (`probar_error`) que captura el error y lo muestra como resultado, así el script corre completo sin cortarse. Si el editor muestra solo el último resultado (como Supabase), se ve esa tabla con los 3 errores esperados.
4. También se pueden correr a mano los comandos que figuran abajo; en ese caso los que dicen **ERROR** van a mostrar el error (es lo esperado) y hay que ejecutarlos de a uno.

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
- Prueba: `CALL devolver_libro(2);` → el préstamo 2 queda con la fecha de hoy y el stock del libro 2 pasa de **2 a 3**.
- Prueba de error: `CALL devolver_libro(1);` → **ERROR: El préstamo 1 ya fue devuelto el 2026-09-10**

## Paso 4 – Triggers

**BEFORE INSERT en `prestamos`** (`trg_validar_prestamo`): antes de guardar el préstamo revisa:
- que el socio exista y esté activo;
- que el libro tenga stock (reutiliza `libro_disponible`).

Si algo falla, lanza `RAISE EXCEPTION` con un mensaje claro. Si todo está bien termina con `RETURN NEW` (sin eso el INSERT se cancelaría sin avisar).
- Prueba: `INSERT INTO prestamos (id_socio, id_libro) VALUES (4, 1);` → **ERROR: ... el socio 4 no está activo**
- Prueba: `INSERT INTO prestamos (id_socio, id_libro) VALUES (1, 5);` → **ERROR: ... el libro 5 no tiene stock**

**AFTER INSERT en `prestamos`** (`trg_descontar_stock`): después de guardar el préstamo, resta 1 al stock del libro.
- Prueba: ver `SELECT stock FROM libros WHERE id_libro = 4;` → **4**. Luego `INSERT INTO prestamos (id_socio, id_libro) VALUES (2, 4);` y volver a consultar → **3**.

## Bonus – Trigger de auditoría
**AFTER DELETE en `prestamos`** (`trg_auditar_borrado_prestamo`): guarda en `auditoria_prestamos` la acción `'DELETE'` y el id del préstamo borrado. Termina con `RETURN OLD`.
- Prueba: `DELETE FROM prestamos WHERE id_prestamo = 7;` (el que se creó en la prueba anterior) y luego `SELECT * FROM auditoria_prestamos;` → una fila con `DELETE` y `id_prestamo = 7`.
