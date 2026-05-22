# Makefile para Shopping Comparator Federation

.PHONY: hub-up hub-down node-up node-down

# Hub Central
hub-up:
	docker-compose -f docker-compose-hub.yml up -d --build

hub-down:
	docker-compose -f docker-compose-hub.yml down

# Nó de Estabelecimento (L1)
node-up:
	docker-compose -f docker-compose-node.yml up -d --build

node-down:
	docker-compose -f docker-compose-node.yml down

# Logs
hub-logs:
	docker-compose -f docker-compose-hub.yml logs -f

node-logs:
	docker-compose -f docker-compose-node.yml logs -f
