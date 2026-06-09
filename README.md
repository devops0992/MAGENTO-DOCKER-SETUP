# Magento 2.4.6 Dockerized Infrastructure on AWS

## Overview

This project demonstrates a production-style Magento 2.4.6 deployment using Docker containers on AWS EC2. The solution includes Nginx, Varnish, PHP-FPM, MySQL, Redis, Elasticsearch, phpMyAdmin, and a dedicated Cron container.

The architecture is designed to provide:

* HTTPS-enabled storefront and admin access
* Full Page Caching using Varnish
* Redis-backed caching and sessions
* Elasticsearch-powered catalog search
* Containerized deployment using Docker Compose
* Persistent storage through Docker volumes
* Dedicated cron execution for Magento scheduled tasks

---

## Architecture Diagram

```text
                    ┌────────────────────┐
                    │      Internet      │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │  AWS EC2 Instance  │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │       NGINX        │
                    │ SSL Termination    │
                    │ Ports 80 / 443     │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │      VARNISH       │
                    │ Full Page Cache    │
                    │ Port 6081          │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │ Internal NGINX     │
                    │ Port 8080          │
                    └─────────┬──────────┘
                              │
                              ▼
                    ┌────────────────────┐
                    │      PHP-FPM       │
                    │ Magento 2.4.6      │
                    └─────┬─────┬────────┘
                          │     │
          ┌───────────────┘     └───────────────┐
          ▼                                     ▼

 ┌────────────────┐                 ┌────────────────┐
 │     Redis      │                 │ Elasticsearch │
 │ Cache/Sessions │                 │ Catalog Search│
 └────────────────┘                 └────────────────┘

                          │
                          ▼

                 ┌────────────────┐
                 │     MySQL      │
                 │ Magento DB     │
                 └────────────────┘

                          │
                          ▼

                 ┌────────────────┐
                 │ Magento Cron   │
                 │ Scheduled Jobs │
                 └────────────────┘
```

---

## Request Flow

### Frontend Request Flow

```text
User Browser
      │
      ▼
HTTPS Request
      │
      ▼
NGINX (443 SSL)
      │
      ▼
Varnish Cache
      │
      ├──────────────► Cache HIT
      │                     │
      │                     ▼
      │               Response
      │
      ▼
Cache MISS
      │
      ▼
Internal NGINX (8080)
      │
      ▼
PHP-FPM
      │
      ├────────► Redis
      │
      ├────────► Elasticsearch
      │
      └────────► MySQL
                    │
                    ▼
              HTML Response
                    │
                    ▼
                Varnish
                    │
                    ▼
                Browser
```

---

## Container Architecture

| Container     | Purpose                         |
| ------------- | ------------------------------- |
| nginx         | Reverse Proxy & SSL Termination |
| varnish       | Full Page Cache                 |
| php-fpm       | Magento Application Runtime     |
| cron          | Magento Scheduled Jobs          |
| mysql         | Magento Database                |
| redis         | Cache & Session Storage         |
| elasticsearch | Product Search Engine           |
| phpmyadmin    | Database Management             |

---

## Technology Stack

* Magento 2.4.6
* Docker Compose
* AWS EC2
* Nginx
* Varnish 7.5
* PHP-FPM 8.1
* MySQL 8.0
* Redis 7
* Elasticsearch 7.17
* phpMyAdmin

---

## Features Implemented

### Infrastructure

* Dockerized Magento deployment
* Multi-container architecture
* Custom Docker networking
* Persistent Docker volumes
* Environment-based configuration

### Security

* HTTPS enabled
* SSL/TLS termination at Nginx
* Security headers configured
* Restricted access to sensitive Magento directories

### Performance

* Varnish Full Page Cache
* Redis caching
* Browser caching for static assets
* Elasticsearch indexing

### Operations

* Dedicated Magento Cron container
* Health monitoring via Docker
* Container restart policies
* Volume persistence

---

## Deployment Validation

### Verify Containers

```bash
docker ps
```

### Verify Magento

```bash
curl -k https://test.dyna.com
```

### Verify Cache

```bash
curl -I -k https://test.dyna.com
```

Expected Header:

```text
X-Magento-Cache-Debug: HIT
```

### Verify Indexers

```bash
docker exec -it magento-php-fpm php bin/magento indexer:status
```

### Verify Cron

```bash
docker exec -it magento-php-fpm php bin/magento cron:run
```

---

## Repository Structure

```text
MAGENTO-DOCKER-SETUP/
│
├── docker/
│   ├── nginx/
│   ├── php-fpm/
│   └── varnish/
│
├── certs/
│
├── docker-compose.yml
├── Dockerfile
├── .env
└── README.md
```

---

## Learning Outcomes

This project provided hands-on experience with:

* Docker Containerization
* Magento Infrastructure Management
* AWS EC2 Administration
* Linux System Administration
* Nginx Configuration
* Varnish Caching
* Redis Integration
* Elasticsearch Integration
* SSL/TLS Configuration
* DevOps Troubleshooting

---

## Author

**Ashish Jadhav**

GitHub:
https://github.com/devops0992/MAGENTO-DOCKER-SETUP
