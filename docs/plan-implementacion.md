# Plan de Implementación — storeApp en Minikube

## Stack

| Componente | Tecnología |
|---|---|
| Lenguaje | Java 21 |
| Framework | Spring Boot 3.x |
| Base de datos | PostgreSQL |
| Contenedor | Docker |
| Orquestador local | Minikube |
| Ingress Controller | nginx (addon Minikube) |

---

## Fase 1 — Entorno local

### 1.1 Instalar herramientas

```bash
# Minikube
brew install minikube

# kubectl
brew install kubectl

# Docker Desktop
# descargar desde docker.com/products/docker-desktop

# Java 21
brew install openjdk@21

# Maven
brew install maven
```

### 1.2 Levantar Minikube

```bash
minikube start --cpus=4 --memory=6144

# Habilitar Ingress (equivalente al HAProxy de OpenShift)
minikube addons enable ingress

# Verificar
minikube status
kubectl get nodes
```

---

## Fase 2 — Microservicio storeApp

### 2.1 Estructura del proyecto

```
storeApp/
├── src/
│   └── main/
│       ├── java/com/store/
│       │   ├── StoreAppApplication.java
│       │   ├── controller/
│       │   │   └── ProductoController.java
│       │   ├── model/
│       │   │   └── Producto.java
│       │   ├── repository/
│       │   │   └── ProductoRepository.java
│       │   └── service/
│       │       └── ProductoService.java
│       └── resources/
│           ├── application.properties
│           └── data.sql
├── Dockerfile
└── pom.xml
```

### 2.2 pom.xml

```xml
<project>
    <groupId>com.store</groupId>
    <artifactId>storeApp</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>

    <properties>
        <java.version>21</java.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
            <scope>runtime</scope>
        </dependency>
    </dependencies>
</project>
```

### 2.3 Modelo — Producto.java

```java
@Entity
@Table(name = "productos")
public class Producto {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String nombre;
    private String marca;
    private String procesador;
    private Integer ram;
    private Double precio;
    private String descripcion;

    // getters y setters
}
```

### 2.4 Repository — ProductoRepository.java

```java
@Repository
public interface ProductoRepository extends JpaRepository<Producto, Long> {
}
```

### 2.5 Service — ProductoService.java

```java
@Service
public class ProductoService {

    private final ProductoRepository repository;

    public ProductoService(ProductoRepository repository) {
        this.repository = repository;
    }

    public List<Producto> listar() {
        return repository.findAll();
    }

    public Optional<Producto> buscarPorId(Long id) {
        return repository.findById(id);
    }
}
```

### 2.6 Controller — ProductoController.java

```java
@RestController
@RequestMapping("/api/productos")
public class ProductoController {

    private final ProductoService service;

    public ProductoController(ProductoService service) {
        this.service = service;
    }

    @GetMapping
    public List<Producto> listar() {
        return service.listar();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Producto> buscarPorId(@PathVariable Long id) {
        return service.buscarPorId(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
}
```

### 2.7 application.properties

```properties
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
```

### 2.8 data.sql — datos iniciales

```sql
INSERT INTO productos (nombre, marca, procesador, ram, precio, descripcion)
VALUES
  ('MacBook Pro 14', 'Apple', 'M4 Pro', 24, 2499.00, 'Laptop profesional Apple'),
  ('ThinkPad X1 Carbon', 'Lenovo', 'Intel i7-1365U', 16, 1899.00, 'Ultrabook empresarial'),
  ('Dell XPS 15', 'Dell', 'Intel i9-13900H', 32, 2199.00, 'Laptop de alto rendimiento'),
  ('HP Spectre x360', 'HP', 'Intel i7-1355U', 16, 1599.00, 'Convertible premium'),
  ('ASUS ROG Zephyrus', 'ASUS', 'AMD Ryzen 9', 32, 1999.00, 'Laptop gaming');
```

### 2.9 Dockerfile

```dockerfile
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY target/storeApp-1.0.0.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

---

## Fase 3 — Kubernetes YAMLs

### 3.1 Namespace

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: storeapp
```

### 3.2 PostgreSQL — Deployment + Service

```yaml
# postgres.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: storeapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          envFrom:
            - secretRef:
                name: postgres-secret
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: storeapp
spec:
  selector:
    app: postgres
  ports:
    - port: 5432
      targetPort: 5432
```

### 3.3 Secret — credenciales PostgreSQL

```yaml
# secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: storeapp
type: Opaque
stringData:
  POSTGRES_DB: storedb
  POSTGRES_USER: storeuser
  POSTGRES_PASSWORD: storepass
```

### 3.4 ConfigMap — configuración storeApp

```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: storeapp-config
  namespace: storeapp
data:
  DB_URL: jdbc:postgresql://postgres:5432/storedb
  DB_USER: storeuser
```

### 3.5 storeApp — Deployment + Service

```yaml
# storeapp.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: storeapp
  namespace: storeapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: storeapp
  template:
    metadata:
      labels:
        app: storeapp
    spec:
      containers:
        - name: storeapp
          image: storeapp:1.0.0
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: storeapp-config
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgres-secret
                  key: POSTGRES_PASSWORD
---
apiVersion: v1
kind: Service
metadata:
  name: storeapp
  namespace: storeapp
spec:
  selector:
    app: storeapp
  ports:
    - port: 8080
      targetPort: 8080
```

### 3.6 Ingress (equivalente al Route de OpenShift)

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: storeapp
  namespace: storeapp
spec:
  rules:
    - host: storeapp.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: storeapp
                port:
                  number: 8080
```

---

## Fase 4 — Build y despliegue

```bash
# 1. Compilar el JAR
mvn clean package -DskipTests

# 2. Apuntar Docker al registry de Minikube
eval $(minikube docker-env)

# 3. Construir la imagen dentro de Minikube
docker build -t storeapp:1.0.0 .

# 4. Aplicar todos los YAMLs
kubectl apply -f namespace.yaml
kubectl apply -f secret.yaml
kubectl apply -f configmap.yaml
kubectl apply -f postgres.yaml
kubectl apply -f storeapp.yaml
kubectl apply -f ingress.yaml

# 5. Verificar que todo está corriendo
kubectl get pods -n storeapp
kubectl get svc -n storeapp
kubectl get ingress -n storeapp
```

---

## Fase 5 — Probar el servicio

```bash
# Agregar entrada en /etc/hosts
echo "$(minikube ip) storeapp.local" | sudo tee -a /etc/hosts

# Probar endpoints
curl http://storeapp.local/api/productos

curl http://storeapp.local/api/productos/1
```

### Respuesta esperada

```json
[
  {
    "id": 1,
    "nombre": "MacBook Pro 14",
    "marca": "Apple",
    "procesador": "M4 Pro",
    "ram": 24,
    "precio": 2499.00,
    "descripcion": "Laptop profesional Apple"
  },
  {
    "id": 2,
    "nombre": "ThinkPad X1 Carbon",
    "marca": "Lenovo",
    "procesador": "Intel i7-1365U",
    "ram": 16,
    "precio": 1899.00,
    "descripcion": "Ultrabook empresarial"
  }
]
```

---

## Fase 6 — Equivalencia OpenShift vs Minikube

| OpenShift (producción) | Minikube (POC) |
|---|---|
| `oc apply` | `kubectl apply` |
| Route | Ingress |
| HAProxy Router | nginx Ingress Controller |
| ImageStream | imagen Docker local |
| Namespace | Namespace |
| Secret | Secret |
| ConfigMap | ConfigMap |
| Deployment | Deployment |
| Service | Service |

---

## Resumen de archivos a crear

```
storeApp/
├── src/...                        ← código Java
├── Dockerfile                     ← imagen Docker
├── pom.xml                        ← dependencias
└── k8s/
    ├── namespace.yaml
    ├── secret.yaml
    ├── configmap.yaml
    ├── postgres.yaml
    ├── storeapp.yaml
    └── ingress.yaml
```
