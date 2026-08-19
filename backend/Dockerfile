# Production image for the Nursify Ktor backend.
# Multi-stage: build a runnable distribution with Gradle, then run it on a slim JRE.
# Designed for Google Cloud Run (reads $PORT) + Neon Postgres (DATABASE_* env).

# ---- build stage ----
FROM gradle:8.7-jdk21 AS build
WORKDIR /app
COPY . .
RUN gradle --no-daemon clean installDist

# ---- runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app
# installDist output: bin/nursify-backend (start script) + lib/*.jar (incl. concepts.json resource)
COPY --from=build /app/build/install/nursify-backend/ ./

# Fit the JVM heap to the container's memory limit (Cloud Run sets one; JDK 21
# is container-aware). Keeps the Netty server comfortably inside 512Mi-1Gi.
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75.0"

# Cloud Run injects $PORT (default 8080); Application.kt binds to it on 0.0.0.0.
EXPOSE 8080
CMD ["./bin/nursify-backend"]
