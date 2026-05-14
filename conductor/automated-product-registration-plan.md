# Plan: Automated Product Registration via Multi-Provider AI Search

Automate product registration by fetching metadata (name, unit, manufacturer) and images from the web using local or cloud AI models, triggered by a barcode scan.

## Objective
Remove manual product entry. When a barcode is scanned and not found, the server will:
1. Search the web for the product.
2. Use an AI (Ollama/Qwen or Gemini) to extract structured data.
3. Download and host the product image in MinIO.
4. Register the product and broadcast it to all clients.

## Key Files & Context
- `server/lib/server.dart`: Main entry point for the backend.
- `server/lib/price_processor.dart`: Existing OCR logic (to be complemented by metadata extraction).
- `client/lib/screens/scan_screen.dart`: UI for scanning and product lookup.
- `client/lib/models/product.dart`: Data model for products.

## Implementation Steps

### 1. Backend: AI & Search Infrastructure
- **Dependency Update**: Add `http` (for search/downloads) and `google_generative_ai` (Gemini option) to `server/pubspec.yaml`.
- **AI Provider Pattern**:
    - Create `server/lib/ai_service.dart` with an `AIEngine` interface.
    - Implement `OllamaEngine` (default, zero-cost) and `GeminiEngine` (optional).
- **Web Search Integration**:
    - Implement a simple search wrapper in `server/lib/search_service.dart` (using DuckDuckGo or a free API).
- **Metadata Extraction Logic**:
    - Create `server/lib/product_metadata_service.dart` to coordinate Search -> LLM -> JSON parsing.

### 2. Backend: Image Governance
- **Image Downloader**: Add logic to `server/lib/server.dart` to:
    - Receive a public URL from the AI.
    - Download the bytes.
    - Upload to MinIO (reusing `bucketName`).
    - Return the new internal URL.

### 3. Frontend: Scanner Refactoring
- **State Management**:
    - Update `_lookupProduct` in `scan_screen.dart` to show a "Searching Web via AI..." status when the cluster search fails.
- **Workflow Change**:
    - Remove `_showRegisterDialog`. The UI should wait for the `product_registration` message from the WebSocket server.
    - Auto-populate the scanned product once the AI finishes.

### 4. Integration & Orchestration
- **WebSocket Protocol**:
    - Update `product_request` handling in the server to trigger the AI pipeline if the product is missing.
- **Docker/Environment**:
    - Add `AI_PROVIDER` (ollama/gemini), `OLLAMA_URL`, and `GEMINI_API_KEY` to `.env.example`.

## Verification & Testing
- **Unit Test**: Test the AI parsing logic with sample HTML/text snippets from web searches.
- **Integration Test**: Scan a known barcode (e.g., a Coca-Cola bottle) and verify:
    1. No manual dialog appears.
    2. Product name and image appear after a few seconds.
    3. Image is served from the internal MinIO instance.
- **Manual Check**: Verify that `StorageService.products` is updated locally via the WebSocket broadcast.
