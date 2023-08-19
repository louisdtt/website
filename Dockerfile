FROM golang:latest AS builder
WORKDIR /go/src/build
COPY *.go go.* ./
COPY static ./static
RUN go mod tidy
RUN CGO_ENABLED=0 go build -o app .

FROM gcr.io/distroless/static-debian11:nonroot
WORKDIR go/src/app
COPY --from=builder /go/src/build/app ./
EXPOSE 3000
CMD ["./app"]