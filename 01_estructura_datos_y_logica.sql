-- =====================================================================
-- INTEGRADOR BASES DE DATOS - BIBLIOTECA
-- Parte 1: tablas, datos de prueba, funciones, procedimientos y triggers
-- (se puede re-ejecutar completo las veces que haga falta)
-- =====================================================================

-- Eliminar si existen (para poder re-ejecutar el script)
DROP TABLE IF EXISTS auditoria_prestamos;
DROP TABLE IF EXISTS prestamos;
DROP TABLE IF EXISTS socios;
DROP TABLE IF EXISTS libros;

-- Tabla de libros
CREATE TABLE libros (
    id_libro SERIAL PRIMARY KEY,
    titulo VARCHAR(150) NOT NULL,
    autor VARCHAR(100) NOT NULL,
    genero VARCHAR(50),
    stock INT NOT NULL DEFAULT 0
);

-- Tabla de socios
CREATE TABLE socios (
    id_socio SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(150),
    activo BOOLEAN DEFAULT TRUE
);

-- Tabla de préstamos
CREATE TABLE prestamos (
    id_prestamo SERIAL PRIMARY KEY,
    id_socio INT NOT NULL,
    id_libro INT NOT NULL,
    fecha_prestamo DATE DEFAULT CURRENT_DATE,
    fecha_devolucion DATE, -- NULL = todavía no se devolvió
    FOREIGN KEY (id_socio) REFERENCES socios(id_socio),
    FOREIGN KEY (id_libro) REFERENCES libros(id_libro)
);

-- Tabla de auditoría
CREATE TABLE auditoria_prestamos (
    id_auditoria SERIAL PRIMARY KEY,
    accion VARCHAR(20),
    id_prestamo INT,
    fecha TIMESTAMP DEFAULT NOW()
);

-- Libros
INSERT INTO libros (titulo, autor, genero, stock) VALUES
('Rayuela', 'Julio Cortázar', 'Novela', 3),
('Ficciones', 'Jorge Luis Borges', 'Cuentos', 2),
('El Eternauta', 'H. G. Oesterheld', 'Historieta', 1),
('Martín Fierro', 'José Hernández', 'Poesía', 4),
('Cien años de soledad', 'Gabriel García Márquez', 'Novela', 0);

-- Socios
INSERT INTO socios (nombre, apellido, email, activo) VALUES
('Ana', 'López', 'ana@mail.com', TRUE),
('Pedro', 'Martínez', 'pedro@mail.com', TRUE),
('Lucía', 'García', 'lucia@mail.com', TRUE),
('Mateo', 'Ramírez', 'mateo@mail.com', FALSE),
('Sofía', 'Fernández', 'sofia@mail.com', TRUE);

-- Préstamos (se cargan ANTES de crear los triggers, por eso no tocan el stock)
INSERT INTO prestamos (id_socio, id_libro, fecha_prestamo, fecha_devolucion) VALUES
(1, 1, '2026-09-01', '2026-09-10'),
(1, 2, '2026-09-15', NULL),
(2, 3, '2026-09-20', NULL),
(3, 1, '2026-09-22', NULL),
(3, 4, '2026-09-05', '2026-09-12'),
(5, 5, '2026-09-25', NULL);


-- =====================================================================
-- FUNCIONES
-- =====================================================================

-- 1) Cantidad total de préstamos de un socio
CREATE OR REPLACE FUNCTION cantidad_prestamos_socio(p_id_socio INT)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_cantidad INT;
BEGIN
    SELECT COUNT(*)
      INTO v_cantidad
      FROM prestamos
     WHERE id_socio = p_id_socio;

    RETURN v_cantidad;
END;
$$;

-- 2) TRUE si el libro tiene stock > 0, FALSE en caso contrario
--    (si el libro no existe también devuelve FALSE)
CREATE OR REPLACE FUNCTION libro_disponible(p_id_libro INT)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock
      INTO v_stock
      FROM libros
     WHERE id_libro = p_id_libro;

    RETURN COALESCE(v_stock, 0) > 0;
END;
$$;


-- =====================================================================
-- PROCEDIMIENTOS ALMACENADOS
-- =====================================================================

-- 1) Registrar un socio nuevo (queda activo)
CREATE OR REPLACE PROCEDURE registrar_socio(
    p_nombre   VARCHAR,
    p_apellido VARCHAR,
    p_email    VARCHAR
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO socios (nombre, apellido, email, activo)
    VALUES (p_nombre, p_apellido, p_email, TRUE);
END;
$$;

-- 2) Devolver un libro: carga la fecha de devolución y suma 1 al stock
CREATE OR REPLACE PROCEDURE devolver_libro(p_id_prestamo INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_libro         INT;
    v_fecha_devolucion DATE;
BEGIN
    SELECT id_libro, fecha_devolucion
      INTO v_id_libro, v_fecha_devolucion
      FROM prestamos
     WHERE id_prestamo = p_id_prestamo;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El préstamo % no existe', p_id_prestamo;
    END IF;

    IF v_fecha_devolucion IS NOT NULL THEN
        RAISE EXCEPTION 'El préstamo % ya fue devuelto el %', p_id_prestamo, v_fecha_devolucion;
    END IF;

    UPDATE prestamos
       SET fecha_devolucion = CURRENT_DATE
     WHERE id_prestamo = p_id_prestamo;

    UPDATE libros
       SET stock = stock + 1
     WHERE id_libro = v_id_libro;
END;
$$;


-- =====================================================================
-- TRIGGERS
-- =====================================================================

-- 1) BEFORE INSERT: valida socio activo y libro con stock
CREATE OR REPLACE FUNCTION fn_validar_prestamo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    SELECT activo
      INTO v_activo
      FROM socios
     WHERE id_socio = NEW.id_socio;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El socio % no existe', NEW.id_socio;
    END IF;

    IF v_activo IS NOT TRUE THEN
        RAISE EXCEPTION 'No se puede registrar el préstamo: el socio % no está activo', NEW.id_socio;
    END IF;

    IF NOT libro_disponible(NEW.id_libro) THEN
        RAISE EXCEPTION 'No se puede registrar el préstamo: el libro % no tiene stock', NEW.id_libro;
    END IF;

    RETURN NEW;  -- sin esto el INSERT se cancelaría en silencio
END;
$$;

CREATE TRIGGER trg_validar_prestamo
BEFORE INSERT ON prestamos
FOR EACH ROW
EXECUTE FUNCTION fn_validar_prestamo();

-- 2) AFTER INSERT: descuenta 1 al stock del libro prestado
CREATE OR REPLACE FUNCTION fn_descontar_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE libros
       SET stock = stock - 1
     WHERE id_libro = NEW.id_libro;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_descontar_stock
AFTER INSERT ON prestamos
FOR EACH ROW
EXECUTE FUNCTION fn_descontar_stock();

-- BONUS: AFTER DELETE: registra el borrado en auditoria_prestamos
CREATE OR REPLACE FUNCTION fn_auditar_borrado_prestamo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO auditoria_prestamos (accion, id_prestamo)
    VALUES ('DELETE', OLD.id_prestamo);

    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_auditar_borrado_prestamo
AFTER DELETE ON prestamos
FOR EACH ROW
EXECUTE FUNCTION fn_auditar_borrado_prestamo();
