# Self-contained wheel-210 release candidate; independent of the E22 compiler.
# Official Odin dev-2026-10 Linux/amd64 archive and its published SHA256.
FROM ubuntu:24.04 AS build
ARG ODIN_VERSION=dev-2026-10
ARG ODIN_SHA256=c3c8b095621fd0c75f7f73e3a0829f1b4d45324225f20ba11ed8dc4da310a8ab
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl clang lld \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt/odin \
    && curl -fsSL "https://github.com/odin-lang/Odin/releases/download/${ODIN_VERSION}/odin-linux-amd64-${ODIN_VERSION}.tar.gz" -o /tmp/odin.tar.gz \
    && echo "${ODIN_SHA256}  /tmp/odin.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/odin.tar.gz -C /opt/odin --strip-components=1 \
    && rm /tmp/odin.tar.gz
ENV ODIN_ROOT=/opt/odin
ENV PATH="/opt/odin:${PATH}"
WORKDIR /opt/app
COPY *.odin ./
RUN odin version && odin build . -o:speed -no-bounds-check -microarch:native -out:primes-odin-wheel210

FROM ubuntu:24.04 AS runtime
WORKDIR /opt/app
COPY --from=build /opt/app/primes-odin-wheel210 ./primes-odin-wheel210
ENTRYPOINT ["./primes-odin-wheel210"]
