-- =====================================================
-- LIMPIEZA PREVIA (DROP EN ORDEN INVERSO A DEPENDENCIAS)
-- =====================================================
DROP VIEW IF EXISTS vw_resumen_diario_caja CASCADE;
DROP VIEW IF EXISTS vw_pedidos_pendientes_por_estacion CASCADE;

DROP TABLE IF EXISTS operation_logs CASCADE;
DROP TABLE IF EXISTS area_responsables CASCADE;
DROP TABLE IF EXISTS audit_logs CASCADE;
DROP TABLE IF EXISTS asistencias CASCADE;
DROP TABLE IF EXISTS horarios CASCADE;
DROP TABLE IF EXISTS turnos CASCADE;
DROP TABLE IF EXISTS consumo_personal CASCADE;
DROP TABLE IF EXISTS productos_consumo CASCADE;
DROP TABLE IF EXISTS movimientos_caja CASCADE;
DROP TABLE IF EXISTS cierres_caja CASCADE;
DROP TABLE IF EXISTS comprobantes CASCADE;
DROP TABLE IF EXISTS pedidos_cocina CASCADE;
DROP TABLE IF EXISTS detalle_comanda CASCADE;
DROP TABLE IF EXISTS comandas CASCADE;
DROP TABLE IF EXISTS ruta_preparacion CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS categorias_producto CASCADE;
DROP TABLE IF EXISTS mesas CASCADE;
DROP TABLE IF EXISTS estaciones CASCADE;
DROP TABLE IF EXISTS areas CASCADE;
DROP TABLE IF EXISTS pisos CASCADE;
DROP TABLE IF EXISTS usuarios CASCADE;
DROP TABLE IF EXISTS roles_permisos CASCADE;
DROP TABLE IF EXISTS permisos CASCADE;
DROP TABLE IF EXISTS roles CASCADE;

-- =====================================================
-- ENUMS
-- =====================================================
DROP TYPE IF EXISTS estado_comanda_enum CASCADE;
DROP TYPE IF EXISTS estado_detalle_enum CASCADE;
DROP TYPE IF EXISTS tipo_estacion_enum CASCADE;
DROP TYPE IF EXISTS estado_pedido_cocina_enum CASCADE;
DROP TYPE IF EXISTS turno_estado_enum CASCADE;
DROP TYPE IF EXISTS metodo_pago_enum CASCADE;
DROP TYPE IF EXISTS tipo_comprobante_enum CASCADE;

CREATE TYPE estado_comanda_enum AS ENUM ('pendiente','en_preparacion','listo','entregado','cancelado');
CREATE TYPE estado_detalle_enum AS ENUM ('pendiente','en_preparacion','listo','entregado','cancelado');
CREATE TYPE tipo_estacion_enum AS ENUM ('cocina','bar','servicio');
CREATE TYPE estado_pedido_cocina_enum AS ENUM ('pendiente','en_proceso','listo','entregado','cancelado');
CREATE TYPE turno_estado_enum AS ENUM ('programado','asistio','falta','tardanza');
CREATE TYPE metodo_pago_enum AS ENUM ('efectivo','tarjeta','yape','plin','otro');
CREATE TYPE tipo_comprobante_enum AS ENUM ('boleta','factura');

-- =====================================================
-- FUNCIÓN TRIGGER
-- =====================================================
CREATE OR REPLACE FUNCTION set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.fecha_actualizacion = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ROLES Y USUARIOS
-- =====================================================
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) UNIQUE NOT NULL,
    descripcion TEXT,
    nivel_acceso INTEGER NOT NULL
);

CREATE TABLE permisos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    codigo VARCHAR(50) UNIQUE NOT NULL,
    modulo VARCHAR(50) NOT NULL
);

CREATE TABLE roles_permisos (
    rol_id INTEGER NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permiso_id INTEGER NOT NULL REFERENCES permisos(id) ON DELETE CASCADE,
    PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE usuarios (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    dni VARCHAR(20) UNIQUE,
    telefono VARCHAR(20),
    rol_id INTEGER REFERENCES roles(id),
    activo BOOLEAN DEFAULT true,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER usuarios_set_timestamp BEFORE UPDATE ON usuarios
FOR EACH ROW EXECUTE PROCEDURE set_timestamp();

-- =====================================================
-- ESTRUCTURA FÍSICA
-- =====================================================
CREATE TABLE pisos (
    id SERIAL PRIMARY KEY,
    numero INTEGER NOT NULL UNIQUE,
    nombre VARCHAR(50) NOT NULL
);

CREATE TABLE areas (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    piso_id INTEGER NOT NULL REFERENCES pisos(id) ON DELETE CASCADE,
    descripcion TEXT
);

CREATE TABLE estaciones (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    tipo tipo_estacion_enum NOT NULL,
    piso_id INTEGER NOT NULL REFERENCES pisos(id) ON DELETE CASCADE,
    area_id INTEGER REFERENCES areas(id) ON DELETE SET NULL,
    activa BOOLEAN DEFAULT true,
    descripcion TEXT
);

CREATE TABLE mesas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    area_id INTEGER REFERENCES areas(id) ON DELETE SET NULL,
    capacidad INTEGER NOT NULL,
    estado VARCHAR(20) DEFAULT 'disponible',
    posicion_x DECIMAL(10,2),
    posicion_y DECIMAL(10,2)
);

CREATE INDEX idx_mesas_area ON mesas(area_id);
CREATE INDEX idx_estaciones_piso_area ON estaciones(piso_id, area_id);

-- =====================================================
-- CATEGORÍAS Y PRODUCTOS
-- =====================================================
CREATE TABLE categorias_producto (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    orden INTEGER,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER categorias_set_timestamp BEFORE UPDATE ON categorias_producto
FOR EACH ROW EXECUTE PROCEDURE set_timestamp();

CREATE TABLE productos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    categoria_id INTEGER REFERENCES categorias_producto(id),
    tiempo_preparacion INTEGER,
    disponible BOOLEAN DEFAULT true,
    imagen_url VARCHAR(500),
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE TRIGGER productos_set_timestamp BEFORE UPDATE ON productos
FOR EACH ROW EXECUTE PROCEDURE set_timestamp();

CREATE TABLE ruta_preparacion (
    producto_id INTEGER REFERENCES productos(id) ON DELETE CASCADE,
    estacion_id INTEGER REFERENCES estaciones(id) ON DELETE CASCADE,
    prioridad INTEGER DEFAULT 1,
    PRIMARY KEY (producto_id, estacion_id)
);
CREATE INDEX idx_ruta_producto ON ruta_preparacion(producto_id);

-- =====================================================
-- COMANDAS Y DETALLES
-- =====================================================
CREATE TABLE comandas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(30) UNIQUE NOT NULL,
    mesa_id INTEGER REFERENCES mesas(id),
    mozo_id INTEGER REFERENCES usuarios(id),
    estado estado_comanda_enum DEFAULT 'pendiente',
    subtotal DECIMAL(12,2) DEFAULT 0,
    igv DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    observaciones TEXT,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_cierre TIMESTAMP WITH TIME ZONE,
    anulada BOOLEAN DEFAULT false
);
CREATE INDEX idx_comandas_mesa ON comandas(mesa_id);

CREATE TABLE detalle_comanda (
    id SERIAL PRIMARY KEY,
    comanda_id INTEGER NOT NULL REFERENCES comandas(id) ON DELETE CASCADE,
    producto_id INTEGER NOT NULL REFERENCES productos(id),
    cantidad INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    estado estado_detalle_enum DEFAULT 'pendiente',
    observaciones TEXT,
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    fecha_completado TIMESTAMP WITH TIME ZONE
);
CREATE INDEX idx_detalle_comanda_comanda ON detalle_comanda(comanda_id);

-- =====================================================
-- PEDIDOS A ESTACIONES
-- =====================================================
CREATE TABLE pedidos_cocina (
    id SERIAL PRIMARY KEY,
    detalle_comanda_id INTEGER NOT NULL REFERENCES detalle_comanda(id) ON DELETE CASCADE,
    estacion_id INTEGER NOT NULL REFERENCES estaciones(id),
    estado estado_pedido_cocina_enum DEFAULT 'pendiente',
    prioridad INTEGER DEFAULT 0,
    responsable_id INTEGER REFERENCES usuarios(id),
    fecha_inicio TIMESTAMP WITH TIME ZONE,
    fecha_fin TIMESTAMP WITH TIME ZONE,
    tiempo_real INTEGER
);
CREATE INDEX idx_pedidos_estacion_estado ON pedidos_cocina(estacion_id, estado);

-- =====================================================
-- FACTURACIÓN Y CAJA
-- =====================================================
CREATE TABLE cierres_caja (
    id SERIAL PRIMARY KEY,
    cajero_id INTEGER REFERENCES usuarios(id),
    fecha_apertura TIMESTAMP WITH TIME ZONE NOT NULL,
    fecha_cierre TIMESTAMP WITH TIME ZONE,
    monto_inicial DECIMAL(12,2) NOT NULL,
    total_efectivo DECIMAL(12,2) DEFAULT 0,
    total_tarjeta DECIMAL(12,2) DEFAULT 0,
    total_digital DECIMAL(12,2) DEFAULT 0,
    total_ventas DECIMAL(14,2) DEFAULT 0,
    diferencia DECIMAL(12,2) DEFAULT 0,
    observaciones TEXT
);
CREATE INDEX idx_cierresfechas ON cierres_caja(fecha_apertura, fecha_cierre);

CREATE TABLE movimientos_caja (
    id SERIAL PRIMARY KEY,
    cierre_id INTEGER REFERENCES cierres_caja(id),
    tipo_movimiento VARCHAR(20) NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    descripcion TEXT,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    origen VARCHAR(100)
);

CREATE TABLE comprobantes (
    id SERIAL PRIMARY KEY,
    tipo tipo_comprobante_enum NOT NULL,
    serie VARCHAR(10) NOT NULL,
    numero VARCHAR(20) NOT NULL,
    comanda_id INTEGER REFERENCES comandas(id),
    cliente_nombre VARCHAR(200),
    cliente_documento VARCHAR(20),
    cliente_direccion TEXT,
    subtotal DECIMAL(12,2) NOT NULL,
    igv DECIMAL(12,2) NOT NULL,
    total DECIMAL(12,2) NOT NULL,
    metodo_pago metodo_pago_enum,
    cajero_id INTEGER REFERENCES usuarios(id),
    fecha_emision TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    anulado BOOLEAN DEFAULT false,
    fecha_actualizacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (tipo, serie, numero)
);
CREATE TRIGGER comprobantes_set_timestamp BEFORE UPDATE ON comprobantes
FOR EACH ROW EXECUTE PROCEDURE set_timestamp();

-- =====================================================
-- INVENTARIO
-- =====================================================
CREATE TABLE productos_consumo (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    categoria VARCHAR(100),
    unidad_medida VARCHAR(20),
    stock_actual DECIMAL(12,2) DEFAULT 0,
    stock_minimo DECIMAL(12,2),
    precio_unitario DECIMAL(12,2)
);

CREATE TABLE consumo_personal (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    producto_consumo_id INTEGER REFERENCES productos_consumo(id),
    cantidad DECIMAL(12,2) NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    aprobado_por INTEGER REFERENCES usuarios(id),
    observaciones TEXT
);

-- =====================================================
-- TURNOS Y ASISTENCIAS
-- =====================================================
CREATE TABLE turnos (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    descripcion TEXT
);

CREATE TABLE horarios (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    fecha DATE NOT NULL,
    turno_id INTEGER REFERENCES turnos(id),
    area_id INTEGER REFERENCES areas(id),
    estado turno_estado_enum DEFAULT 'programado',
    observaciones TEXT,
    creado_por INTEGER REFERENCES usuarios(id),
    fecha_creacion TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE asistencias (
    id SERIAL PRIMARY KEY,
    horario_id INTEGER REFERENCES horarios(id) ON DELETE CASCADE,
    usuario_id INTEGER REFERENCES usuarios(id),
    hora_entrada TIMESTAMP WITH TIME ZONE,
    hora_salida TIMESTAMP WITH TIME ZONE,
    estado turno_estado_enum DEFAULT 'programado',
    registrado_por INTEGER REFERENCES usuarios(id),
    observaciones TEXT
);

-- =====================================================
-- LOGS Y AUDITORÍA
-- =====================================================
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    tabla_nombre VARCHAR(100),
    fila_id INTEGER,
    accion VARCHAR(20),
    usuario_id INTEGER REFERENCES usuarios(id),
    cambios JSONB,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE area_responsables (
    area_id INTEGER REFERENCES areas(id) ON DELETE CASCADE,
    usuario_id INTEGER REFERENCES usuarios(id) ON DELETE CASCADE,
    rol_desempeno VARCHAR(50),
    PRIMARY KEY (area_id, usuario_id)
);

CREATE TABLE operation_logs (
    id SERIAL PRIMARY KEY,
    usuario_id INTEGER REFERENCES usuarios(id),
    accion VARCHAR(150),
    detalles TEXT,
    fecha TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- VISTAS
-- =====================================================
CREATE VIEW vw_pedidos_pendientes_por_estacion AS
SELECT pc.estacion_id,
       e.nombre AS estacion_nombre,
       pc.id AS pedido_id,
       dc.id AS detalle_comanda_id,
       dc.comanda_id,
       dc.producto_id,
       p.nombre AS producto_nombre,
       dc.cantidad,
       pc.estado,
       pc.prioridad,
       pc.responsable_id
FROM pedidos_cocina pc
JOIN detalle_comanda dc ON pc.detalle_comanda_id = dc.id
JOIN productos p ON dc.producto_id = p.id
JOIN estaciones e ON e.id = pc.estacion_id
WHERE pc.estado IN ('pendiente','en_proceso')
ORDER BY pc.prioridad DESC, pc.fecha_inicio NULLS FIRST;

CREATE VIEW vw_resumen_diario_caja AS
SELECT date(tr.fecha_emision) as fecha,
       SUM(CASE WHEN tr.metodo_pago = 'efectivo' THEN tr.total ELSE 0 END) as total_efectivo,
       SUM(CASE WHEN tr.metodo_pago = 'tarjeta' THEN tr.total ELSE 0 END) as total_tarjeta,
       SUM(CASE WHEN tr.metodo_pago IN ('yape','plin') THEN tr.total ELSE 0 END) as total_digital,
       COUNT(*) as total_comprobantes,
       SUM(tr.total) as total_ventas
FROM comprobantes tr
WHERE tr.anulado = false
GROUP BY date(tr.fecha_emision)
ORDER BY date(tr.fecha_emision) DESC;
