--FUNCIONES CHISTOSAS

--Total de basura
CREATE OR REPLACE FUNCTION TotalBasuraRecolectada(fecha_inicio DATE, fecha_fin DATE)
RETURNS DECIMAL(10, 2) AS $$
DECLARE
    total_kg DECIMAL(10, 2);
BEGIN
    SELECT SUM(Cantidad_Kg) INTO total_kg
    FROM Basura b
    JOIN Horarios h ON b.ID_Horario = h.ID
    WHERE h.Fecha BETWEEN fecha_inicio AND fecha_fin;
    
    RETURN COALESCE(total_kg, 0); -- Para evitar errores regresa 0 si no encuentra datos (me trone la base de datos 1 vez)
END;
$$ LANGUAGE plpgsql;


--Voluntarios por playa
CREATE OR REPLACE FUNCTION VoluntariosPorPlaya(nombre_playa VARCHAR(100))
RETURNS TABLE (
    Nombre_Voluntario VARCHAR(100),
    Email VARCHAR(100),
    Telefono VARCHAR(15)
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.Nombre, u.Email, ut.Telefono
    FROM Usuario u
    JOIN Usuario_Telefono ut ON u.ID = ut.ID_Usuario
    JOIN Usuario_Rol ur ON u.ID = ur.ID_Usuario
    JOIN Registro r ON u.ID = r.ID_Usuario
    JOIN Horarios h ON r.ID_Horario = h.ID
    JOIN Playa p ON h.ID_Playa = p.ID
    WHERE p.Nombre = nombre_playa AND ur.Rol = 'Voluntario';
END;
$$ LANGUAGE plpgsql;


--Estadisticas, 
CREATE OR REPLACE FUNCTION CalcularImpacto(id_horario INT)
RETURNS VARCHAR(50) AS $$
DECLARE
    cantidad_kg DECIMAL(10, 2);
    resultado VARCHAR(50);
BEGIN
    SELECT Cantidad_Kg INTO cantidad_kg
    FROM Basura
    WHERE ID_Horario = id_horario;
    
    IF cantidad_kg IS NULL THEN
        resultado := 'Sin datos';
    ELSIF cantidad_kg < 10 THEN
        resultado := 'Bajo impacto';
    ELSIF cantidad_kg BETWEEN 10 AND 50 THEN
        resultado := 'Impacto moderado';
    ELSE
        resultado := 'Alto impacto';
    END IF;
    
    RETURN resultado;
END;
$$ LANGUAGE plpgsql;


--ALMACENADOS
CREATE OR REPLACE PROCEDURE RegistrarVoluntarioEnHorario(
    id_usuario INT,
    id_horario INT
) AS $$
DECLARE
    cupo_actual INT;
    cupo_maximo INT;
BEGIN
    --No se pueden registrar organizadores
    IF NOT EXISTS (SELECT 1 FROM Usuario_Rol WHERE ID_Usuario = id_usuario AND Rol = 'Voluntario') THEN
        RAISE EXCEPTION 'Error no es un voluntarios';
    END IF;
    
    -- Verifica que haya cupo por así decirlo
    SELECT COUNT(*), h.Cupo_Maximo INTO cupo_actual, cupo_maximo
    FROM Registro r
    JOIN Horarios h ON r.ID_Horario = h.ID
    WHERE r.ID_Horario = id_horario
    GROUP BY h.Cupo_Maximo;
    
    IF cupo_actual >= cupo_maximo THEN
        RAISE EXCEPTION 'Cupo lleno';
    END IF;
    
    INSERT INTO Registro (ID_Usuario, ID_Horario) VALUES (id_usuario, id_horario);
    RAISE NOTICE 'Voluntario registrado en resumen no hay error';
END;
$$ LANGUAGE plpgsql;

--Proceso para actualizar la basura
CREATE OR REPLACE PROCEDURE ActualizarBasura(
    id_horario_param INT,
    nueva_cantidad DECIMAL(10, 2)
) AS $$
BEGIN
    IF nueva_cantidad < 0 THEN
        RAISE EXCEPTION 'Basura negativa todavía más prueba inteligencia';
    END IF;
    
    UPDATE Basura
    SET Cantidad_Kg = nueva_cantidad
    WHERE ID_Horario = id_horario_param;
    
    RAISE NOTICE '¡Bien hecho!';
END;
$$ LANGUAGE plpgsql;


--VISTAS
--Horarios disponibles
CREATE OR REPLACE VIEW HorariosDisponibles AS
SELECT h.ID, p.Nombre AS Playa, h.Fecha, h.Hora_Inicio, h.Hora_Fin
FROM Horarios h
JOIN Playa p ON h.ID_Playa = p.ID
WHERE h.Estado = 'En Proceso'
AND (SELECT COUNT(*) FROM Registro WHERE ID_Horario = h.ID) < h.Cupo_Maximo;


--Consulta basica para cada playa
CREATE OR REPLACE VIEW ResumenPorPlaya AS
SELECT p.Nombre, SUM(b.Cantidad_Kg) AS Total_Kg, COUNT(DISTINCT r.ID_Usuario) AS Voluntarios
FROM Playa p
JOIN Horarios h ON p.ID = h.ID_Playa
JOIN Basura b ON h.ID = b.ID_Horario
JOIN Registro r ON h.ID = r.ID_Horario
GROUP BY p.Nombre;

--Detakes
CREATE OR REPLACE VIEW DetalleVoluntarios AS
SELECT 
    u.Nombre,
    u.Email,
    COUNT(r.ID) AS Total_Inscripciones,
    CASE 
        WHEN COUNT(r.ID) = 0 THEN 'Nuevo'
        WHEN COUNT(r.ID) BETWEEN 1 AND 3 THEN 'Activo'
        ELSE 'Experto'
    END AS Categoria
FROM Usuario u
LEFT JOIN Registro r ON u.ID = r.ID_Usuario
GROUP BY u.ID, u.Nombre, u.Email;

--triggers

CREATE OR REPLACE FUNCTION ValidarFechaHorario()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.Fecha < CURRENT_DATE THEN
        RAISE EXCEPTION 'Ya paso la fecha, por así decirlo no hay caballo más adelante';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER TriggerValidarFecha
BEFORE INSERT OR UPDATE ON Horarios
FOR EACH ROW EXECUTE FUNCTION ValidarFechaHorario();




--Si fecha ya paso estado de horario se completa
CREATE OR REPLACE FUNCTION ActualizarEstadoHorario()
RETURNS TRIGGER AS $$
DECLARE
    cupo_actual INT;
    cupo_maximo INT;
BEGIN
    SELECT COUNT(*), h.Cupo_Maximo INTO cupo_actual, cupo_maximo
    FROM Registro r
    JOIN Horarios h ON r.ID_Horario = h.ID
    WHERE r.ID_Horario = NEW.ID_Horario
    GROUP BY h.Cupo_Maximo;
    
    IF cupo_actual >= cupo_maximo THEN
        UPDATE Horarios SET Estado = 'Completa' WHERE ID = NEW.ID_Horario;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER TriggerActualizarEstado
AFTER INSERT ON Registro
FOR EACH ROW EXECUTE FUNCTION ActualizarEstadoHorario();
