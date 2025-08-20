FROM golang:1.24.5-alpine AS build
ENV GOTOOLCHAIN=auto
WORKDIR /app

# unduh deps dulu biar cache efisien
COPY go.mod go.sum ./
RUN go mod download

# baru copy source
COPY . .
RUN go build -o /bin/indexer ./cmd/recording-indexer

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=build /bin/indexer /usr/local/bin/indexer
ENTRYPOINT ["indexer"]
