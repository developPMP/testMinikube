# storeApp

API REST de productos construida con Spring Boot 3 + PostgreSQL, desplegable en Docker local o Minikube.

---

## Requisitos

- Java 21
- Maven 3.9+
- Docker Desktop

---

## Infraestructura local (Docker)

### Levantar PostgreSQL

```bash
docker run -d \
  --name storeapp-postgres \
  -e POSTGRES_DB=storedb \
  -e POSTGRES_USER=storeuser \
  -e POSTGRES_PASSWORD=storepass \
  -p 5432:5432 \
  postgres:16-alpine
```

### Verificar que está corriendo

```bash
docker ps --filter name=storeapp-postgres
```

### Detener PostgreSQL

```bash
docker stop storeapp-postgres
```

### Volver a levantar (si ya existe el contenedor)

```bash
docker start storeapp-postgres
```

### Eliminar contenedor y datos

```bash
docker stop storeapp-postgres
docker rm storeapp-postgres
```

---

## Aplicación

### 1. Compilar

```bash
cd storeApp
mvn clean package -DskipTests
```

### 2. Levantar la app

```bash
DB_URL=jdbc:postgresql://localhost:5432/storedb \
DB_USER=storeuser \
DB_PASSWORD=storepass \
java -jar target/storeApp-1.0.0.jar
```

La app queda disponible en `http://localhost:8080`.

### 3. Detener la app

`Ctrl + C` en la terminal donde corre el proceso.

Si corre en background:

```bash
# Buscar el PID
lsof -i :8080

# Matar el proceso
kill <PID>
```

---

## Endpoints

| Método | URL | Descripción |
|--------|-----|-------------|
| GET | `/api/productos` | Lista todos los productos |
| GET | `/api/productos/{id}` | Obtiene un producto por ID |

### Ejemplos

```bash
curl http://localhost:8080/api/productos

curl http://localhost:8080/api/productos/1
```

---

## Despliegue en Minikube

> Minikube usa el **driver Docker** en macOS (corre como contenedor dentro de Docker Desktop).
> La IP interna de Minikube (`192.168.49.2`) **no es accesible directamente** desde el host en macOS,
> por eso se usa `minikube tunnel` para exponer los servicios en `127.0.0.1`.

---

### Instalación de herramientas (una sola vez)

```bash
brew install minikube kubectl
```

---

### Paso 1 — Levantar el cluster (una sola vez o tras `minikube delete`)

```bash
minikube start --cpus=4 --memory=6144
minikube addons enable ingress
```

---

### Paso 2 — Configurar el Ingress Controller como LoadBalancer (una sola vez)

> En macOS con driver Docker, el ingress-nginx viene como `NodePort` por defecto.
> Hay que cambiarlo a `LoadBalancer` para que `minikube tunnel` lo exponga correctamente.

```bash
kubectl patch svc ingress-nginx-controller -n ingress-nginx \
  -p '{"spec":{"type":"LoadBalancer"}}'
```

Verificar que quedó aplicado:

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
# Debe mostrar TYPE: LoadBalancer
```

---

### Paso 3 — Configurar /etc/hosts (una sola vez)

> Apunta `storeapp.local` a `127.0.0.1` (IP que asigna el tunnel), no a la IP de Minikube.

```bash
echo "127.0.0.1 storeapp.local" | sudo tee -a /etc/hosts
```

Verificar:

```bash
grep "storeapp.local" /etc/hosts
# Debe mostrar: 127.0.0.1 storeapp.local
```

---

### Paso 4 — Build de la imagen dentro del cluster

> `minikube docker-env` redirige los comandos Docker al daemon interno de Minikube,
> para que la imagen quede disponible dentro del cluster sin necesidad de un registry externo.

```bash
eval $(minikube docker-env)
mvn clean package -DskipTests
docker build -t storeapp:1.0.0 .
```

---

### Paso 5 — Aplicar manifiestos

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/storeapp.yaml
kubectl apply -f k8s/ingress.yaml
```

---

### Paso 6 — Levantar el tunnel (cada vez que uses Minikube)

> ⚠️ El tunnel debe estar corriendo para que el Ingress sea accesible.
> Pedirá contraseña de sudo. **Déjalo corriendo en una terminal separada, no lo cierres.**

```bash
# Abrir una terminal nueva y ejecutar:
minikube tunnel
```

Verificar que el tunnel asignó la IP (en otra terminal):

```bash
kubectl get svc ingress-nginx-controller -n ingress-nginx
# EXTERNAL-IP debe mostrar: 127.0.0.1
```

---

### Paso 7 — Verificar estado

```bash
kubectl get pods -n storeapp
kubectl get svc -n storeapp
kubectl get ingress -n storeapp
```

Todos los pods deben estar en estado `Running`.

---

### Paso 8 — Probar los endpoints

```bash
# Vía Ingress (requiere tunnel corriendo)
curl http://storeapp.local/api/productos
curl http://storeapp.local/api/productos/1
```

Alternativa sin tunnel (debug rápido):

```bash
kubectl port-forward svc/storeapp 8080:8080 -n storeapp
# En otra terminal:
curl http://localhost:8080/api/productos
```

---

### Retomar después de `minikube stop`

Cuando hayas detenido Minikube y quieras volver a usarlo:

```bash
# 1. Levantar el cluster (recupera el estado anterior automáticamente)
minikube start

# 2. Verificar que los pods están Running
kubectl get pods -n storeapp

# 3. En una terminal separada, levantar el tunnel
minikube tunnel
```

> Los pasos 2, 3 y la configuración de `/etc/hosts` **no se repiten** (ya están hechos).
> Solo se repite `minikube start` y `minikube tunnel` cada vez.

---

### Detener todo

```bash
# 1. Detener el tunnel (en la terminal donde corre: Ctrl+C)
#    Si no encuentras la terminal:
pkill -9 -f "minikube tunnel"

# 2. Eliminar recursos de Kubernetes
kubectl delete -f k8s/

# 3. Detener Minikube (conserva la configuración)
minikube stop

# 4. Eliminar cluster completo (borra todo, requiere reconfigurar desde Paso 1)
minikube delete
```

---

### Solución de problemas

| Problema | Solución |
|----------|----------|
| `TUNNEL_ALREADY_RUNNING` | `kill -9 $(ps aux \| grep "minikube tunnel" \| grep -v grep \| awk '{print $2}')` |
| `EXTERNAL-IP` en `<pending>` | Asegúrate de que el tunnel esté corriendo y el svc sea `LoadBalancer` |
| `Could not resolve host: storeapp.local` | Verificar `/etc/hosts`: debe tener `127.0.0.1 storeapp.local` |
| Puerto 8080 en uso | `kill $(lsof -t -i :8080)` |

---

## Estructura del proyecto

```
storeApp/
├── src/main/java/com/store/
│   ├── StoreAppApplication.java
│   ├── controller/ProductoController.java
│   ├── model/Producto.java
│   ├── repository/ProductoRepository.java
│   └── service/ProductoService.java
├── src/main/resources/
│   ├── application.properties
│   └── data.sql
├── k8s/
│   ├── namespace.yaml
│   ├── secret.yaml
│   ├── configmap.yaml
│   ├── postgres.yaml
│   ├── storeapp.yaml
│   └── ingress.yaml
├── Dockerfile
└── pom.xml
```
