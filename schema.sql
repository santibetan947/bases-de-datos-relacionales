-- =====================================================
-- Cinepailas - Esquema SQL (PostgreSQL + pgvector)
-- =====================================================

CREATE EXTENSION IF NOT EXISTS vector;

-- ---------- Tablas sin dependencias ----------

CREATE TABLE usuario (
    id_usuario SERIAL PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    correo     VARCHAR(100) NOT NULL UNIQUE,
    rol        VARCHAR(10)  NOT NULL CHECK (rol IN ('cliente', 'taquilla'))
);

CREATE TABLE clasificacion (
    id_clasificacion SERIAL PRIMARY KEY,
    nombre           VARCHAR(30) NOT NULL,
    edad_minima      INT NOT NULL
);

CREATE TABLE director (
    id_director  SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    nacionalidad VARCHAR(50)
);

CREATE TABLE genero (
    id_genero SERIAL PRIMARY KEY,
    nombre    VARCHAR(50) NOT NULL
);

CREATE TABLE actor (
    id_actor     SERIAL PRIMARY KEY,
    nombre       VARCHAR(100) NOT NULL,
    nacionalidad VARCHAR(50)
);

CREATE TABLE sala (
    id_sala   SERIAL PRIMARY KEY,
    nombre    VARCHAR(50) NOT NULL,
    capacidad INT NOT NULL CHECK (capacidad > 0)
);

CREATE TABLE metodo_pago (
    id_metodo_pago SERIAL PRIMARY KEY,
    nombre         VARCHAR(30) NOT NULL
);

-- ---------- Películas ----------

CREATE TABLE pelicula (
    id_pelicula      SERIAL PRIMARY KEY,
    titulo           VARCHAR(200) NOT NULL,
    idioma           VARCHAR(30)  NOT NULL,
    fecha_estreno    DATE NOT NULL,
    duracion_min     INT NOT NULL,
    id_clasificacion INT NOT NULL REFERENCES clasificacion(id_clasificacion),
    id_director      INT NOT NULL REFERENCES director(id_director)
);

-- Tablas intermedias (relaciones N a M)
CREATE TABLE pelicula_genero (
    id_pelicula INT NOT NULL REFERENCES pelicula(id_pelicula),
    id_genero   INT NOT NULL REFERENCES genero(id_genero),
    PRIMARY KEY (id_pelicula, id_genero)
);

CREATE TABLE pelicula_actor (
    id_pelicula INT NOT NULL REFERENCES pelicula(id_pelicula),
    id_actor    INT NOT NULL REFERENCES actor(id_actor),
    PRIMARY KEY (id_pelicula, id_actor)
);

-- Un afiche por película (UNIQUE = relación 1 a 1)
CREATE TABLE imagen (
    id_imagen   SERIAL PRIMARY KEY,
    id_pelicula INT NOT NULL UNIQUE REFERENCES pelicula(id_pelicula),
    url_imagen  TEXT NOT NULL
);

-- Sinopsis y reseñas (tipo = 'sinopsis' o 'resena')
-- id_usuario y calificacion solo se llenan en las reseñas
CREATE TABLE documento (
    id_documento SERIAL PRIMARY KEY,
    id_pelicula  INT NOT NULL REFERENCES pelicula(id_pelicula),
    id_usuario   INT REFERENCES usuario(id_usuario),
    tipo         VARCHAR(10) NOT NULL CHECK (tipo IN ('sinopsis', 'resena')),
    texto        TEXT NOT NULL,
    calificacion INT CHECK (calificacion BETWEEN 1 AND 5),
    fecha        DATE NOT NULL
);

-- ---------- Funciones y boletas ----------

CREATE TABLE funcion (
    id_funcion  SERIAL PRIMARY KEY,
    id_pelicula INT NOT NULL REFERENCES pelicula(id_pelicula),
    id_sala     INT NOT NULL REFERENCES sala(id_sala),
    fecha_hora  TIMESTAMP NOT NULL,
    precio      NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    UNIQUE (id_sala, fecha_hora)   -- no dos funciones en la misma sala a la misma hora
);

CREATE TABLE boleta (
    id_boleta           SERIAL PRIMARY KEY,
    id_funcion          INT NOT NULL REFERENCES funcion(id_funcion),
    id_usuario_cliente  INT NOT NULL REFERENCES usuario(id_usuario),
    id_usuario_taquilla INT NOT NULL REFERENCES usuario(id_usuario),
    id_metodo_pago      INT NOT NULL REFERENCES metodo_pago(id_metodo_pago),
    fecha_compra        TIMESTAMP NOT NULL,
    valor               NUMERIC(10,2) NOT NULL CHECK (valor > 0)
);

-- ---------- Consultas del asistente ----------

CREATE TABLE consulta (
    id_consulta   SERIAL PRIMARY KEY,
    id_usuario    INT REFERENCES usuario(id_usuario),
    pregunta      TEXT NOT NULL,
    tipo_consulta VARCHAR(20) NOT NULL,
    fecha_hora    TIMESTAMP NOT NULL
);

-- Cada resultado es un documento O una imagen (el otro queda en NULL)
CREATE TABLE resultado (
    id_resultado SERIAL PRIMARY KEY,
    id_consulta  INT NOT NULL REFERENCES consulta(id_consulta),
    id_documento INT REFERENCES documento(id_documento),
    id_imagen    INT REFERENCES imagen(id_imagen),
    posicion     INT NOT NULL,
    similitud    NUMERIC(6,5)
);

-- Una evaluación por consulta (UNIQUE = relación 1 a 1)
CREATE TABLE evaluacion (
    id_evaluacion       SERIAL PRIMARY KEY,
    id_consulta         INT NOT NULL UNIQUE REFERENCES consulta(id_consulta),
    tiempo_respuesta_ms INT NOT NULL,
    relevancia          NUMERIC(3,2) NOT NULL
);

-- =====================================================
-- Tablas vectoriales
-- =====================================================

CREATE TABLE embeddings_texto (
    id_embedding        SERIAL PRIMARY KEY,
    id_documento        INT NOT NULL REFERENCES documento(id_documento) ON DELETE CASCADE,
    chunk_id            INT NOT NULL,
    estrategia_chunking VARCHAR(20) NOT NULL
        CHECK (estrategia_chunking IN ('fixed-size', 'sentence-aware', 'semantic')),
    chunk_texto         TEXT NOT NULL,
    vector_embedding    VECTOR(384) NOT NULL,
    modelo              VARCHAR(100) NOT NULL,
    UNIQUE (id_documento, estrategia_chunking, chunk_id)
);

CREATE TABLE embeddings_imagen (
    id_embedding     SERIAL PRIMARY KEY,
    id_imagen        INT NOT NULL REFERENCES imagen(id_imagen) ON DELETE CASCADE,
    vector_embedding VECTOR(512) NOT NULL,
    modelo           VARCHAR(100) NOT NULL
);

-- Índices vectoriales
CREATE INDEX ON embeddings_texto  USING hnsw (vector_embedding vector_cosine_ops);
CREATE INDEX ON embeddings_imagen USING hnsw (vector_embedding vector_cosine_ops);