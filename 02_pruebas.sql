-- =====================================================================
-- INTEGRADOR BASES DE DATOS - BIBLIOTECA
-- Parte 2: pruebas (ejecutar DESPUÉS de 01_estructura_datos_y_logica.sql)
-- Ejecutar en orden: los resultados esperados dependen de ese orden.
-- El archivo corre completo sin cortarse: las pruebas que "deben dar error"
-- se ejecutan con la función de ayuda probar_error(), que captura el error
-- y lo muestra como resultado en lugar de frenar el script.
-- (Algunos editores web, como el de Supabase, muestran solo el resultado de
-- la ÚLTIMA consulta: por eso las pruebas de error van al final.)
-- =====================================================================

-- ---------- FUNCIÓN DE AYUDA (solo para probar) ----------
-- Ejecuta una sentencia y devuelve el mensaje de error si falla.
CREATE OR REPLACE FUNCTION probar_error(p_sentencia TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE p_sentencia;
    RETURN 'SIN ERROR (inesperado)';
EXCEPTION WHEN OTHERS THEN
    RETURN 'ERROR: ' || SQLERRM;
END;
$$;


-- ---------- FUNCIONES ----------

-- Esperado: 2
SELECT cantidad_prestamos_socio(1);

-- Esperado: TRUE (libro 1 tiene stock 3)
SELECT libro_disponible(1);

-- Esperado: FALSE (libro 5 tiene stock 0)
SELECT libro_disponible(5);


-- ---------- PROCEDIMIENTO registrar_socio ----------

CALL registrar_socio('Carlos', 'Gómez', 'carlos@mail.com');

-- Esperado: aparece el socio 6, Carlos Gómez, activo = true
SELECT * FROM socios ORDER BY id_socio;


-- ---------- PROCEDIMIENTO devolver_libro ----------

-- Antes: préstamo 2 sin devolver y libro 2 con stock 2
SELECT id_prestamo, fecha_devolucion FROM prestamos WHERE id_prestamo = 2;
SELECT id_libro, stock FROM libros WHERE id_libro = 2;

CALL devolver_libro(2);

-- Después: el préstamo 2 tiene la fecha de hoy y el libro 2 pasó a stock 3
SELECT id_prestamo, fecha_devolucion FROM prestamos WHERE id_prestamo = 2;
SELECT id_libro, stock FROM libros WHERE id_libro = 2;


-- ---------- TRIGGERS ----------

-- Stock del libro 4 antes: 4
SELECT id_libro, titulo, stock FROM libros WHERE id_libro = 4;

-- Socio 2 (activo) pide el libro 4 -> se registra como préstamo 7
INSERT INTO prestamos (id_socio, id_libro) VALUES (2, 4);

-- Stock del libro 4 después: 3
SELECT id_libro, titulo, stock FROM libros WHERE id_libro = 4;
SELECT * FROM prestamos ORDER BY id_prestamo;


-- ---------- BONUS: trigger de auditoría ----------

-- Borramos el préstamo 7 que acabamos de crear
DELETE FROM prestamos WHERE id_prestamo = 7;

-- Esperado: una fila con accion = 'DELETE' e id_prestamo = 7
SELECT * FROM auditoria_prestamos;


-- =====================================================================
-- PRUEBAS QUE DEBEN DAR ERROR (van al final, en una sola consulta)
-- Esperado: las 3 filas muestran un ERROR con el mensaje indicado.
-- =====================================================================

SELECT prueba, probar_error(sentencia) AS resultado
FROM (VALUES
    ('Socio 4 (inactivo) pide el libro 1',
     'INSERT INTO prestamos (id_socio, id_libro) VALUES (4, 1)'),
    ('Socio 1 pide el libro 5 (sin stock)',
     'INSERT INTO prestamos (id_socio, id_libro) VALUES (1, 5)'),
    ('Devolver el préstamo 1 (ya devuelto)',
     'CALL devolver_libro(1)')
) AS t(prueba, sentencia);
