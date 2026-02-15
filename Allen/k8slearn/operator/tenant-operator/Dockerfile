FROM golang:1.17 as builder

WORKDIR /workspace
COPY go.mod ./
RUN go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
RUN go mod download

COPY . ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o manager ./main.go

FROM gcr.io/distroless/static:nonroot
WORKDIR /
COPY --from=builder /workspace/manager /manager
USER 65532:65532
ENTRYPOINT ["/manager"]
