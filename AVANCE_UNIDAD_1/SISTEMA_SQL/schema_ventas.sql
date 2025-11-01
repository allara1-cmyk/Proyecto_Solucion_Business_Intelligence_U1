-- Proyecto: TechStore - Sistema SQL (Ventas)

-- Tabla de clientes
-- Guarda la información de las personas que compran en TechStore.
CREATE TABLE Clientes (
  id_cliente SERIAL PRIMARY KEY,          -- ID único del cliente
  nombre VARCHAR(100) NOT NULL,           -- Nombre del cliente
  email VARCHAR(100) UNIQUE,              -- Correo (no se puede repetir)
  ciudad VARCHAR(50)                      -- Ciudad donde vive
);

-- Tabla de sucursales
-- Contiene las tiendas físicas donde se realizan las ventas.
CREATE TABLE Sucursales (
  id_sucursal SERIAL PRIMARY KEY,         -- ID único de la sucursal
  nombre_sucursal VARCHAR(100) NOT NULL,  -- Nombre de la tienda
  ciudad VARCHAR(50)                      -- Ciudad donde está ubicada
);

-- Tabla de ventas
-- Representa cada venta realizada en una sucursal.
CREATE TABLE Ventas (
  id_venta SERIAL PRIMARY KEY,            -- ID de la venta
  id_cliente INT REFERENCES Clientes(id_cliente),  -- Cliente que compró
  id_sucursal INT REFERENCES Sucursales(id_sucursal), -- Sucursal donde se vendió
  fecha_venta DATE NOT NULL               -- Fecha de la venta
);

-- Tabla de detalle de ventas
-- Aquí se guarda qué productos se vendieron en cada venta.
CREATE TABLE Detalle_Ventas (
  id_detalle SERIAL PRIMARY KEY,          -- ID del detalle
  id_venta INT REFERENCES Ventas(id_venta), -- Relación con la venta principal
  sku_producto VARCHAR(10),               -- SKU del producto (enlace con MongoDB)
  cantidad INT,                           -- Cuántas unidades se vendieron
  precio_venta_momento DECIMAL(10,2)      -- Precio del producto al momento de la venta
);

-- Campo "sku_producto" se conecta con la colección "productos"