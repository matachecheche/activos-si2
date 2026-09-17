-- Datos ficticios para probar la interfaz (Sprint 1)
-- Seguro de correr varias veces: usa ON CONFLICT / valida antes de insertar.

INSERT INTO ubicacion (nombre) VALUES
    ('Almacen central'),
    ('Oficina de sistemas'),
    ('Laboratorio de redes'),
    ('Direccion administrativa'),
    ('Biblioteca')
ON CONFLICT DO NOTHING;

-- Activos ficticios (solo se insertan si la tabla activo tiene menos de 5 registros,
-- para no duplicar si ya corriste este script antes)
DO $$
DECLARE
    cnt INT;
    cat_mobiliario INT;
    cat_equipos INT;
    cat_vehiculos INT;
    cat_maquinaria INT;
    cat_inmuebles INT;
BEGIN
    SELECT COUNT(*) INTO cnt FROM activo;
    IF cnt < 5 THEN
        SELECT id INTO cat_mobiliario FROM categoria WHERE nombre = 'Mobiliario';
        SELECT id INTO cat_equipos FROM categoria WHERE nombre = 'Equipos informaticos';
        SELECT id INTO cat_vehiculos FROM categoria WHERE nombre = 'Vehiculos';
        SELECT id INTO cat_maquinaria FROM categoria WHERE nombre = 'Maquinaria';
        SELECT id INTO cat_inmuebles FROM categoria WHERE nombre = 'Inmuebles';

        INSERT INTO activo (codigo, nombre, categoria_id, valor, fecha_adquisicion, proveedor, estado)
        VALUES
            ('ACT-2026-0001', 'Laptop Dell Latitude 5440', cat_equipos, 8500.00, '2026-01-15', 'Tecnodata SRL', 'SIN_ASIGNAR'),
            ('ACT-2026-0002', 'Laptop HP ProBook 450', cat_equipos, 7900.00, '2026-01-15', 'Tecnodata SRL', 'SIN_ASIGNAR'),
            ('ACT-2026-0003', 'Impresora multifuncional Epson L5590', cat_equipos, 2300.00, '2026-02-02', 'Comercial Andina', 'SIN_ASIGNAR'),
            ('ACT-2026-0004', 'Proyector Epson PowerLite X49', cat_equipos, 3200.00, '2026-02-10', 'Comercial Andina', 'MANTENIMIENTO'),
            ('ACT-2026-0005', 'Escritorio ejecutivo de melamina', cat_mobiliario, 950.00, '2026-01-20', 'Muebleria San Martin', 'SIN_ASIGNAR'),
            ('ACT-2026-0006', 'Silla ergonomica giratoria', cat_mobiliario, 480.00, '2026-01-20', 'Muebleria San Martin', 'SIN_ASIGNAR'),
            ('ACT-2026-0007', 'Archivador metalico 4 gavetas', cat_mobiliario, 620.00, '2026-01-25', 'Muebleria San Martin', 'SIN_ASIGNAR'),
            ('ACT-2026-0008', 'Vehiculo Toyota Hilux 2024', cat_vehiculos, 245000.00, '2026-03-05', 'Toyotasa', 'SIN_ASIGNAR'),
            ('ACT-2026-0009', 'Motocicleta Honda CB125', cat_vehiculos, 12500.00, '2026-03-10', 'Motos del Oriente', 'BAJA'),
            ('ACT-2026-0010', 'Generador electrico 5kva', cat_maquinaria, 9800.00, '2026-02-18', 'Ferreteria Central', 'SIN_ASIGNAR'),
            ('ACT-2026-0011', 'Aire acondicionado split 24000 BTU', cat_maquinaria, 5400.00, '2026-02-20', 'ClimaTech', 'SIN_ASIGNAR'),
            ('ACT-2026-0012', 'Edificio Bloque C - Facultad', cat_inmuebles, 1850000.00, '2020-01-01', 'N/A', 'SIN_ASIGNAR')
        ON CONFLICT (codigo) DO NOTHING;
    END IF;
END $$;

-- Asignaciones ficticias: se asignan algunos activos a los usuarios de prueba
DO $$
DECLARE
    u_encargado INT;
    u_contador INT;
    ub_oficina INT;
    ub_almacen INT;
    act1 INT;
    act2 INT;
BEGIN
    SELECT id INTO u_encargado FROM usuario WHERE correo = 'encargado@uagrm.edu.bo';
    SELECT id INTO u_contador  FROM usuario WHERE correo = 'contador@uagrm.edu.bo';
    SELECT id INTO ub_oficina  FROM ubicacion WHERE nombre = 'Oficina de sistemas';
    SELECT id INTO ub_almacen  FROM ubicacion WHERE nombre = 'Almacen central';
    SELECT id INTO act1 FROM activo WHERE codigo = 'ACT-2026-0001';
    SELECT id INTO act2 FROM activo WHERE codigo = 'ACT-2026-0005';

    IF u_encargado IS NOT NULL AND act1 IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM asignacion WHERE activo_id = act1 AND activa = TRUE) THEN
        INSERT INTO asignacion (activo_id, responsable_id, ubicacion_id, fecha_asignacion, activa)
        VALUES (act1, u_encargado, ub_oficina, NOW(), TRUE);
        UPDATE activo SET responsable_id = u_encargado, ubicacion_id = ub_oficina, estado = 'EN_USO' WHERE id = act1;
    END IF;

    IF u_contador IS NOT NULL AND act2 IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM asignacion WHERE activo_id = act2 AND activa = TRUE) THEN
        INSERT INTO asignacion (activo_id, responsable_id, ubicacion_id, fecha_asignacion, activa)
        VALUES (act2, u_contador, ub_almacen, NOW(), TRUE);
        UPDATE activo SET responsable_id = u_contador, ubicacion_id = ub_almacen, estado = 'EN_USO' WHERE id = act2;
    END IF;
END $$;