# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY client/pubspec.* ./
RUN flutter pub get

COPY client/ .
RUN flutter build web --release --base-href "/app/" -O4 --no-web-resources-cdn

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy landing page to root
COPY web-server/index.html /usr/share/nginx/html/index.html

# Copy Flutter build to /app subdirectory
COPY --from=build /app/build/web /usr/share/nginx/html/app

COPY web-server/default.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
