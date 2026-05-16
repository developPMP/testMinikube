INSERT INTO productos (nombre, marca, procesador, ram, precio, descripcion)
SELECT 'MacBook Pro 14', 'Apple', 'M4 Pro', 24, 2499.00, 'Laptop profesional Apple'
WHERE NOT EXISTS (SELECT 1 FROM productos LIMIT 1);

INSERT INTO productos (nombre, marca, procesador, ram, precio, descripcion)
SELECT 'ThinkPad X1 Carbon', 'Lenovo', 'Intel i7-1365U', 16, 1899.00, 'Ultrabook empresarial'
WHERE NOT EXISTS (SELECT 1 FROM productos LIMIT 1);

INSERT INTO productos (nombre, marca, procesador, ram, precio, descripcion)
SELECT 'Dell XPS 15', 'Dell', 'Intel i9-13900H', 32, 2199.00, 'Laptop de alto rendimiento'
WHERE NOT EXISTS (SELECT 1 FROM productos LIMIT 1);

INSERT INTO productos (nombre, marca, procesador, ram, precio, descripcion)
SELECT 'HP Spectre x360', 'HP', 'Intel i7-1355U', 16, 1599.00, 'Convertible premium'
WHERE NOT EXISTS (SELECT 1 FROM productos LIMIT 1);

INSERT INTO productos (nombre, marca, procesador, ram, precio, descripcion)
SELECT 'ASUS ROG Zephyrus', 'ASUS', 'AMD Ryzen 9', 32, 1999.00, 'Laptop gaming'
WHERE NOT EXISTS (SELECT 1 FROM productos LIMIT 1);
