FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart pub get --offline
RUN dart compile exe bin/hub.dart -o /app/bin/hub

FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/hub /app/bin/hub

EXPOSE 3001
CMD ["/app/bin/hub"]
