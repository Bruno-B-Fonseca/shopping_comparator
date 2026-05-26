# Makefile para Shopping Comparator Federation

.PHONY: hub-up hub-down node-up node-down up down

# All-in-One (Hub + Node Local)
up:
	docker-compose up -d --build

down:
	docker-compose down

# Hub Central
hub-up:
	docker-compose -f docker-compose-hub.yml up -d --build

hub-down:
	docker-compose -f docker-compose-hub.yml down

# Nó de Estabelecimento (L1)
node-up:
	docker-compose -f docker-compose-node.yml up -d --build
	@echo "🔍 Aguardando URL do túnel Cloudflare (Quick Tunnel)..."
	@for i in {1..15}; do \
		URL=$$(docker-compose -f docker-compose-node.yml logs tunnel 2>&1 | grep -o 'https://[^ ]*\.trycloudflare\.com' | head -n 1); \
		if [ -n "$$URL" ]; then \
			WS_URL=$$(echo $$URL | sed 's/https:\/\//wss:\/\//')/ws; \
			echo "✅ URL Detectada: $$URL"; \
			echo "📡 Anunciando no Hub via Node: $$WS_URL"; \
			sleep 3; \
			curl -s -X POST http://localhost:3000/api/announce-url \
				-H "Content-Type: application/json" \
				-d "{\"url\": \"$$WS_URL\"}"; \
			echo "\n🚀 Nó registrado com sucesso no Hub Nacional!"; \
			break; \
		fi; \
		echo "Aguardando túnel... ($$i/15)"; \
		sleep 3; \
	done

node-down:
	docker-compose -f docker-compose-node.yml down

# Logs
hub-logs:
	docker-compose -f docker-compose-hub.yml logs -f

node-logs:
	docker-compose -f docker-compose-node.yml logs -f
