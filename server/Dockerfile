# Use the official Dart image
FROM dart:stable

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
