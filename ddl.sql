CREATE TABLE Usuario (
    ID SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Email VARCHAR(100) NOT NULL UNIQUE,
    Fecha_Registro TIMESTAMP DEFAULT NOW()
);


CREATE TABLE Usuario_Telefono ( 
    ID_Usuario INT REFERENCES Usuario(ID),
    Telefono VARCHAR(15) NOT NULL,
    PRIMARY KEY (ID_Usuario, Telefono)
);

CREATE TYPE TipoRol AS ENUM ('Voluntario', 'Organizador'); --Roles

CREATE TABLE Usuario_Rol (
    ID_Usuario INT REFERENCES Usuario(ID),
    Rol TipoRol NOT NULL,
    PRIMARY KEY (ID_Usuario, Rol)
);

CREATE TABLE Playa (
    ID SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE Horarios (
    ID SERIAL PRIMARY KEY,
    ID_Playa INT REFERENCES Playa(ID) NOT NULL,
    Fecha DATE NOT NULL CHECK (Fecha > CURRENT_DATE),
    Hora_Inicio TIME NOT NULL,
    Hora_Fin TIME NOT NULL CHECK (Hora_Fin > Hora_Inicio),
    Estado VARCHAR(20) CHECK (Estado IN ('Completa', 'En Proceso')),
    Cupo_Maximo INT DEFAULT 20
);

CREATE TABLE Registro (
    ID SERIAL PRIMARY KEY,
    ID_Usuario INT REFERENCES Usuario(ID) NOT NULL,
    ID_Horario INT REFERENCES Horarios(ID) NOT NULL,
    UNIQUE (ID_Usuario, ID_Horario)
);




CREATE TABLE Basura (
    ID SERIAL PRIMARY KEY,
    ID_Horario INT REFERENCES Horarios(ID) NOT NULL UNIQUE,
    Cantidad_Kg DECIMAL(10,2) NOT NULL CHECK (Cantidad_Kg >= 0)
);

CREATE TABLE Material (
    ID SERIAL PRIMARY KEY,
    Nombre VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE Basura_Material (
    ID_Basura INT REFERENCES Basura(ID),
    ID_Material INT REFERENCES Material(ID),
    Cantidad_Kg DECIMAL(10,2) CHECK (Cantidad_Kg >= 0), --no puede haber basura negativa
    PRIMARY KEY (ID_Basura, ID_Material)
);