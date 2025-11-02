## Proyecto: TechStore – Modelo Dual de Bases de Datos (SQL + NoSQL)  
**Autor:** Lara Chicaiza Anderson Lenin  
**Asignatura:** Modelado Avanzado de Base de Datos – 6to ITIN  

---

# 1. Justificación del Modelo Dual (SQL para ventas, NoSQL para productos)

### Contexto de TechStore

- **Ventas:** son transacciones **OLTP**, con escritura frecuente, alta concurrencia y necesidad de **consistencia inmediata** e **integridad referencial** (Clientes, Sucursales, Ventas, Detalle_Ventas).  
- **Productos:** poseen **atributos flexibles** (por categoría: smartphones, laptops, monitores), cambian constantemente y requieren ajustes sin migraciones de esquema.

---

### SQL para Ventas

1. **Consistencia:** garantiza que cada venta y su detalle se registren de forma atómica y segura.  
2. **Integridad referencial:** evita huérfanos mediante claves foráneas entre tablas.  
3. **Consultas transaccionales:** permite filtros y joins eficientes por cliente, sucursal o fecha.  
4. **Auditoría y trazabilidad:** facilita colocar registros “quién, cuándo, antes/después” en operaciones CRUD.

---

### NoSQL (MongoDB) para Productos

1. **Esquema flexible:** el subdocumento `especificaciones` admite variaciones por categoría.  
2. **Evolución rápida:** permite incorporar nuevos atributos sin afectar otros documentos.  
3. **Lecturas completas:** ideal para APIs que obtienen todo el producto en una sola consulta.  
4. **Escalabilidad horizontal:** mediante sharding y replicación.

---

### Vinculación SQL vs NoSQL

- Clave común: **`sku` (MongoDB)** - **`Detalle_Ventas.sku_producto` (SQL)**.  
- En el siguiente avance con **Data Mart de Ventas**, los productos se podrían integrarar como **dimensión de producto (DIM Producto)**, combinando hechos de ventas con el catálogo de MongoDB.

---

# 2. Informe de Calidad de Datos

Se detallan **3 problemas críticos** y **2 adicionales** con:  
(a) detección, (b) prevención/corrección y (c) su impacto en BI.

---

## Problema 1:

### Inconsistencia entre `sku_producto` (SQL) y catálogo de productos (MongoDB)

En el modelo dual de **TechStore**, puede presentarse una inconsistencia cuando la tabla **`Detalle_Ventas`** del sistema **SQL** registra un valor en el campo `sku_producto` que **no tiene una correspondencia válida** en la colección **`productos`** de **MongoDB**.  
Esto significa que el sistema está almacenando una venta asociada a un producto que **no existe en el catálogo oficial**.

Por ejemplo, si en SQL se registra una transacción con el código **`SKU999`**, pero dicho código no existe en MongoDB, se produce una ruptura en la integridad de los datos.  
Este tipo de error puede originarse por las siguientes causas:

- **Errores de digitación** en el código del producto.  
- **Actualizaciones o eliminaciones no sincronizadas** entre ambas bases de datos.  
- **Falta de validaciones** en la capa de aplicación o en los procesos ETL.

Como consecuencia, se generan **ventas de productos “fantasma”**, afectando la exactitud de los reportes y distorsionando los indicadores de desempeño, como los **productos más vendidos**, las **tendencias por categoría** o los **ingresos totales por línea**.  
En un entorno de **inteligencia de negocios (BI)**, este tipo de inconsistencias compromete la **confiabilidad del análisis** y puede conducir a **decisiones erróneas** basadas en información incompleta o inexacta.

#### Posible Solución

- **Validar el `sku` antes de registrar una venta**: la capa de aplicación debe verificar que el producto exista en MongoDB antes de permitir su inserción en la tabla `Detalle_Ventas`.  
- **Sincronizar catálogos** de manera periódica entre el sistema SQL (ventas) y MongoDB (productos), garantizando que los códigos de producto sean consistentes.  
- **Implementar controles en el proceso ETL**, de forma que, durante la carga al Data Mart, se comparen los SKUs de ambas fuentes y se excluyan o etiqueten los que no tengan correspondencia.  
- **Definir reglas de integridad operativa**, evitando que se registre una venta con un SKU que no figure en el catálogo.

## Problema 2: 

### Duplicidad de `sku` en MongoDB

En la colección **`productos`** del sistema **MongoDB**, puede presentarse una inconsistencia cuando existen **dos o más documentos con el mismo código `sku`**, el cual debería identificar de forma única a cada producto dentro del catálogo.  
Esto ocurre cuando no se define un **índice único** que impida insertar valores repetidos, permitiendo que un mismo artículo se registre varias veces con ligeras variaciones en sus datos.

Por ejemplo, podrían existir dos documentos distintos con el código **`SKU123`**, ambos haciendo referencia al producto *“Samsung Galaxy S24”*, pero con diferencias en su nombre o precio.  
Este problema suele originarse por:

- **Errores durante la carga de datos**.  
- **Ausencia de validaciones** en los procesos **ETL**.  
- **Inserciones manuales no controladas** o sin verificación previa.

---

#### Detección

Para identificar estos casos, se agrupan los productos por su campo `sku` y se listan aquellos que aparecen más de una vez:

```js
db.productos.aggregate([
  { $group: { _id: "$sku", count: { $sum: 1 } } },
  { $match: { count: { $gt: 1 } } }
]);

```

#### Posible Solución

- Crear un índice único que impida registros duplicados:
```js

db.productos.createIndex({ sku: 1 }, { unique: true });

```
- Consolidar los registros repetidos, conservar el documento maestro y actualizar las referencias asociadas.
- Implementar validaciones automáticas en los procesos de carga y sincronización.

## Problema 3:

**Datos no Controlados en la BDD** 

Existen registros donde el campo `email` se encuentra vacío, nulo o con un formato incorrecto.  
Esto ocurre por la falta de validaciones en los formularios de ingreso o en los procesos ETL de carga de datos.

   **Ejemplo de registros inválidos:**

   | id_cliente | nombre         | email              |
   |-------------|----------------|--------------------|
   | 1           | Carlos Torres  | *(nulo)*           |
   | 2           | Ana López      | ana.lopez@         |
   | 3           | Luis Andrade   | luis.andradegmail.com |

Se registran ventas con **cantidades iguales o menores a cero** o con **fechas posteriores a la actual**, lo que representa un error lógico en el sistema.

   **Ejemplo de registros anómalos:**

   | id_venta | fecha_venta | cantidad | total |
   |-----------|--------------|-----------|--------|
   | 10        | 2026-02-01   | 1         | 450.00 |
   | 11        | 2025-12-15   | 0         | 0.00   |
   | 12        | 2024-11-20   | -2        | -300.00 |

#### Posible Solución

- **Validación de datos en la capa de aplicación (backend/UI):**  
  Implementar controles en los formularios o interfaces de registro que verifiquen que:
  - El campo `email` no esté vacío y cumpla el formato válido.  
  - No se permita registrar ventas con cantidad menor o igual que 0 ni con `fecha_venta` posterior a la actual.

- **Controles en los procesos ETL:**  
  Durante la carga de datos hacia el sistema o el Data Mart, aplicar reglas de validación que:
  - Detecten correos inválidos o nulos y los registren en una tabla de errores.  
  - Excluyan o corrijan registros con cantidades negativas o fechas fuera de rango.

- **Restricciones estructurales en SQL:**  
  Definir políticas a nivel de base de datos que impidan el ingreso de datos inconsistentes