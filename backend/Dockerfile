FROM eclipse-temurin:25-jdk

WORKDIR /app

COPY pom.xml .
COPY src ./src

RUN apt-get update \
    && apt-get install -y maven \
    && mvn clean package -DskipTests \
    && apt-get clean

EXPOSE 8080

CMD ["java", "-jar", "target/activos-backend-0.0.1-SNAPSHOT.jar"]
