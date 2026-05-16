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

> Minikube es una herramienta que se instala directamente en la PC y levanta un cluster Kubernetes local.
> No es una imagen Docker ni corre como contenedor.

### Instalación de herramientas (una sola vez)

```bash
brew install minikube kubectl
```

### Levantar el cluster

```bash
minikube start --cpus=4 --memory=6144
minikube addons enable ingress
```

### Build de la imagen de la app dentro del cluster

> `minikube docker-env` redirige los comandos Docker al daemon interno de Minikube,
> para que la imagen quede disponible dentro del cluster sin necesidad de un registry externo.

```bash
eval $(minikube docker-env)
mvn clean package -DskipTests
docker build -t storeapp:1.0.0 .
```

### Aplicar manifiestos

```bash
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/secret.yaml
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/storeapp.yaml
kubectl apply -f k8s/ingress.yaml
```

### Verificar estado

```bash
kubectl get pods -n storeapp
kubectl get svc -n storeapp
kubectl get ingress -n storeapp
```

### Acceder vía Ingress

```bash
# Agregar entrada en /etc/hosts (una sola vez)
echo "$(minikube ip) storeapp.local" | sudo tee -a /etc/hosts

curl http://storeapp.local/api/productos
```

### Detener todo en Minikube

```bash
kubectl delete -f k8s/
```

### Detener Minikube

```bash
minikube stop
```

### Eliminar cluster completo

```bash
minikube delete
```

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
