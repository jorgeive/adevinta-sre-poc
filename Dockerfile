FROM gradle:4.7.0-jdk8-alpine AS build
COPY --chown=gradle:gradle app/* /home/gradle/src/
WORKDIR /home/gradle/src
RUN gradle wrapper
RUN ./gradlew build

FROM openjdk:8-jre-slim
EXPOSE 8080
COPY --from=build /home/gradle/src/build/libs/helloworld-0.0.1-SNAPSHOT.jar /usr/src/myapp/helloworld-0.0.1-SNAPSHOT.jar
WORKDIR /usr/src/myapp/
ENTRYPOINT ["java", "-jar", "helloworld-0.0.1-SNAPSHOT.jar", "--spring.profiles.active=pro"]