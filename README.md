# Dify with Ollama Integration

This project sets up Dify with Ollama for local LLM integration.

## Prerequisites

- Docker and Docker Compose installed
- At least 16GB RAM recommended
- Sufficient disk space for models

## Quick Start

### 1. Start All Services

Run these commands from the project root:

```bash
# Navigate to Dify directory
cd dify/docker

# Start Dify services
docker compose up -d

# Navigate to LLM directory
cd ../../LLM

# Start LLM services (Ollama + Open WebUI)
docker compose up -d
```

### 2. Access the Services

- **Dify Dashboard**: http://localhost
- **Open WebUI**: http://localhost:3000
- **Ollama API**: http://localhost:11434

## Managing Services

### Stop All Services

```bash
# Stop Dify services
cd dify/docker
docker-compose -f docker-compose-template.yaml down

# Stop LLM services
cd ../../LLM
docker-compose down
```

### Check Service Status

```bash
# Check all running containers
docker ps

# Check Dify containers specifically
docker ps | grep dify

# Check LLM containers specifically
docker ps | grep ollama
```

### View Logs

```bash
# View Dify API logs
cd dify/docker
docker-compose -f docker-compose-template.yaml logs -f api

# View Dify Worker logs
cd dify/docker
docker-compose -f docker-compose-template.yaml logs -f worker

# View Ollama logs
cd ../../LLM
docker-compose logs -f ollama

# View Open WebUI logs
cd ../../LLM
docker-compose logs -f open-webui
```

### Clean Up (Remove All Data)

```bash
# Remove Dify containers and volumes
cd dify/docker
docker-compose -f docker-compose-template.yaml down -v

# Remove LLM containers and volumes
cd ../../LLM
docker-compose down -v

# Remove all unused Docker images and volumes
docker system prune -a
```# FishFish
