# Arquitectura — storeApp

---

## Diagrama general

```mermaid
graph TD
    User(["👤 Cliente\n(curl / browser)"])

    subgraph Mac["💻 macOS Host"]
        Hosts["/etc/hosts\nstoreapp.local → 127.0.0.1"]
        Tunnel["minikube tunnel\n(127.0.0.1:80)"]
    end

    subgraph DockerDesktop["🐳 Docker Desktop"]
        subgraph Minikube["📦 Minikube (contenedor)"]

            subgraph IngressNS["Namespace: ingress-nginx"]
                IngressCtrl["Ingress Controller\nnginx (LoadBalancer)\nEXTERNAL-IP: 127.0.0.1"]
            end

            subgraph NS["Namespace: storeapp"]
                Ingress["Ingress\nhost: storeapp.local\npath: /"]

                subgraph Config["Configuración"]
                    CM["ConfigMap\nstoreapp-config\nDB_URL, DB_USER"]
                    Secret["Secret\npostgres-secret\nDB_PASSWORD"]
                end

                SvcApp["Service\nstoreapp\nClusterIP :8080"]
                SvcDB["Service\npostgres\nClusterIP :5432"]

                subgraph Pods["Pods"]
                    Pod1["Pod storeapp (1)\nSpring Boot 3\n:8080"]
                    Pod2["Pod storeapp (2)\nSpring Boot 3\n:8080"]
                    PodDB["Pod postgres\nPostgreSQL 16\n:5432"]
                end
            end
        end
    end

    User -->|"GET storeapp.local/api/productos"| Hosts
    Hosts --> Tunnel
    Tunnel --> IngressCtrl
    IngressCtrl --> Ingress
    Ingress --> SvcApp
    SvcApp --> Pod1
    SvcApp --> Pod2
    Pod1 -->|"JDBC"| SvcDB
    Pod2 -->|"JDBC"| SvcDB
    SvcDB --> PodDB
    CM -->|"env vars"| Pod1
    CM -->|"env vars"| Pod2
    Secret -->|"env vars"| Pod1
    Secret -->|"env vars"| Pod2
    Secret -->|"env vars"| PodDB
```

---

## Diagrama de capas de la aplicación (Spring Boot)

```mermaid
graph TD
    HTTP["HTTP Request\nGET /api/productos\nGET /api/productos/{id}"]

    subgraph SpringBoot["Spring Boot 3 — storeapp:1.0.0"]
        Controller["ProductoController\n@RestController"]
        Service["ProductoService\n@Service"]
        Repository["ProductoRepository\n@Repository (JPA)"]
        Model["Producto\n@Entity"]
    end

    DB[("PostgreSQL 16\nstoredb")]

    HTTP --> Controller
    Controller --> Service
    Service --> Repository
    Repository --> Model
    Repository -->|"SQL"| DB
```

---

## Diagrama de manifiestos Kubernetes

```mermaid
graph LR
    subgraph k8s["k8s/ — Manifiestos"]
        NS["namespace.yaml\nNamespace: storeapp"]
        CM["configmap.yaml\nDB_URL\nDB_USER"]
        SEC["secret.yaml\nDB_PASSWORD\nPOSTGRES_*"]
        PG["postgres.yaml\nDeployment + Service\nreplicas: 1"]
        APP["storeapp.yaml\nDeployment + Service\nreplicas: 2"]
        ING["ingress.yaml\nIngress nginx\nstoreapp.local → svc:8080"]
    end

    NS --> CM
    NS --> SEC
    NS --> PG
    NS --> APP
    NS --> ING
    CM -->|"envFrom"| APP
    SEC -->|"env"| APP
    SEC -->|"envFrom"| PG
```

---

## Flujo de red en macOS (Docker driver)

```mermaid
sequenceDiagram
    actor User as 👤 Cliente
    participant Hosts as /etc/hosts
    participant Tunnel as minikube tunnel
    participant Nginx as Ingress nginx
    participant Svc as Service storeapp
    participant Pod as Pod storeapp
    participant DB as PostgreSQL

    User->>Hosts: GET http://storeapp.local/api/productos
    Hosts-->>User: storeapp.local → 127.0.0.1
    User->>Tunnel: HTTP :80 → 127.0.0.1
    Tunnel->>Nginx: reenvía al Ingress Controller
    Nginx->>Svc: match host + path /
    Svc->>Pod: balancea entre réplicas (pod1 o pod2)
    Pod->>DB: consulta JDBC → postgres:5432
    DB-->>Pod: resultado SQL
    Pod-->>User: JSON [ { id, nombre, precio, ... } ]
```

---

## Resumen de componentes

| Componente | Tipo | Namespace | Puerto | Réplicas |
|------------|------|-----------|--------|----------|
| `storeapp` | Deployment + Service | `storeapp` | 8080 | 2 |
| `postgres` | Deployment + Service | `storeapp` | 5432 | 1 |
| `storeapp` (ingress) | Ingress | `storeapp` | 80 | — |
| `ingress-nginx-controller` | Service LoadBalancer | `ingress-nginx` | 80/443 | — |
| `storeapp-config` | ConfigMap | `storeapp` | — | — |
| `postgres-secret` | Secret | `storeapp` | — | — |

