# Use the official Dart image
FROM dart:stable

# Install Tesseract OCR
RUN apt-get update && apt-get install -y tesseract-ocr && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Ensure we start with a clean state by ignoring host artifacts via .dockerignore
# Copy pubspec and install dependencies
COPY pubspec.* ./
RUN dart pub get

# Copy the rest of the code
COPY . .

# Expose the port
EXPOSE 3000

# Run using JIT for better reliability during development
# We use 'dart run' which handles package resolution correctly
CMD ["dart", "run", "bin/server.dart"]
