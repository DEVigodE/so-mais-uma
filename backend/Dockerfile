# syntax=docker/dockerfile:1

# ---- build: compila e empacota com o Maven Wrapper (testes rodam na CI, não aqui)
FROM eclipse-temurin:25-jdk AS build
WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw && ./mvnw -B -q dependency:go-offline
COPY src/ src/
RUN ./mvnw -B -q package -DskipTests && cp target/so-mais-uma-*.jar app.jar

# ---- runtime: apenas a JRE e o jar, executando sem root
FROM eclipse-temurin:25-jre
WORKDIR /app
RUN useradd --system --uid 10001 app
COPY --from=build /app/app.jar app.jar
USER app
ENV SPRING_PROFILES_ACTIVE=simulado \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75"
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
