FROM golang:1.23-alpine AS build
WORKDIR /app
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download && \
    go build -o push-service ./cmd/push-service

FROM alpine:3.19
WORKDIR /app
COPY --from=build /app/push-service /app/push-service
COPY --from=build /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
EXPOSE 8090
ENTRYPOINT ["/app/push-service"]
