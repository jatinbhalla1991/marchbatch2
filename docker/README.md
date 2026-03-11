# Docker Examples - Usage Guide

## Files Created:

### 1. docker-compose.yaml
Simple docker-compose for your index.html with Nginx

**Usage:**
```bash
cd docker
docker-compose up -d
# Access at: http://localhost:8080
docker-compose down
```

### 2. Dockerfile.multistage
Multi-stage build example for React/Node.js applications

**Benefits:**
- Reduces final image size by 70-80%
- Separates build and runtime environments
- Improves security

**Build:**
```bash
docker build -f Dockerfile.multistage -t myapp:multistage .
```

### 3. Dockerfile.java-multistage
Multi-stage build for Java/Maven applications

**Build:**
```bash
docker build -f Dockerfile.java-multistage -t javaapp:multistage .
```

**Run:**
```bash
docker run -p 8080:8080 javaapp:multistage
```

### 4. docker-compose.advanced.yaml
Full-stack application with multiple services

**Includes:**
- Frontend (Nginx)
- Backend (Node.js)
- Database (PostgreSQL)
- Cache (Redis)

**Usage:**
```bash
docker-compose -f docker-compose.advanced.yaml up -d
docker-compose -f docker-compose.advanced.yaml ps
docker-compose -f docker-compose.advanced.yaml logs -f
docker-compose -f docker-compose.advanced.yaml down -v
```

## Common Commands:

### Docker Compose
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f [service_name]

# Stop services
docker-compose down

# Rebuild and start
docker-compose up -d --build

# Remove volumes
docker-compose down -v
```

### Docker
```bash
# Build image
docker build -t imagename:tag .

# Run container
docker run -d -p 8080:80 imagename:tag

# List containers
docker ps

# Stop container
docker stop container_id

# Remove container
docker rm container_id
```

## Multi-Stage Build Advantages:

1. **Smaller Image Size**: Only includes runtime dependencies
2. **Security**: Build tools not present in production image
3. **Cache Optimization**: Better layer caching
4. **Clean Separation**: Build and runtime concerns separated
