.PHONY: help build up down logs install clean restart

help:
	@echo "Magento 2 Docker Environment"
	@echo "============================"
	@echo ""
	@echo "Available commands:"
	@echo "  make build       - Build Docker images"
	@echo "  make up          - Start all containers"
	@echo "  make down        - Stop all containers"
	@echo "  make logs        - View container logs"
	@echo "  make install     - Install Magento 2"
	@echo "  make clean       - Remove containers and volumes"
	@echo "  make restart     - Restart all containers"
	@echo "  make shell       - Shell into PHP container"
	@echo ""

build:
	docker-compose build

up:
	docker-compose up -d

down:
	docker-compose down

logs:
	docker-compose logs -f

logs-%:
	docker-compose logs -f $*

install:
	@echo "Installing Magento 2..."
	docker-compose exec -T php-fpm php bin/magento setup:install \
		--base-url=https://test.dyna.com/ \
		--base-url-secure=https://test.dyna.com/ \
		--db-host=mysql \
		--db-name=$${MYSQL_DATABASE} \
		--db-user=$${MYSQL_USER} \
		--db-password=$${MYSQL_PASSWORD} \
		--admin-firstname=Admin \
		--admin-lastname=User \
		--admin-email=admin@test.dyna.com \
		--admin-user=admin \
		--admin-password=Admin@123456 \
		--language=en_US \
		--currency=USD \
		--timezone=UTC \
		--search-engine=elasticsearch \
		--elasticsearch-host=elasticsearch \
		--elasticsearch-port=9200
	@echo ""
	@echo "Installing sample data..."
	docker-compose exec -T php-fpm php bin/magento sampledata:deploy
	docker-compose exec -T php-fpm php bin/magento setup:upgrade
	docker-compose exec -T php-fpm php bin/magento setup:static-content:deploy en_US
	@echo "Installation complete!"

clean:
	docker-compose down -v
	rm -rf var/ pub/media/ pub/static/ generated/

restart:
	docker-compose restart

shell:
	docker-compose exec php-fpm sh

shell-db:
	docker-compose exec mysql mysql -u$${MYSQL_USER} -p$${MYSQL_PASSWORD} $${MYSQL_DATABASE}

status:
	docker-compose ps

purge-cache:
	docker-compose exec -T php-fpm php bin/magento cache:flush

reindex:
	docker-compose exec -T php-fpm php bin/magento indexer:reindex

setup-admin-url:
	docker-compose exec -T php-fpm php bin/magento config:set admin/url/custom admin_$(shell date +%s)/

setup-redis:
	docker-compose exec -T php-fpm php bin/magento config:set system/full_page_cache/caching_application 2
	docker-compose exec -T php-fpm php bin/magento config:set system/cache/backend redis
	docker-compose exec -T php-fpm php bin/magento config:set system/cache/backend_options/server redis
	docker-compose exec -T php-fpm php bin/magento config:set system/cache/backend_options/port 6379
	docker-compose exec -T php-fpm php bin/magento config:set system/cache/backend_options/database 0

setup-varnish:
	docker-compose exec -T php-fpm php bin/magento config:set system/full_page_cache/caching_application 2
