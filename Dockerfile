FROM public.ecr.aws/ubuntu/ubuntu:24.04 AS build

ARG ODIN_SOURCE_COMMIT=b277d66e008e15d640208f3e11515b047f78be48
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates git clang-18 llvm-18-dev lld-18 g++ make \
    && ln -s /usr/bin/clang-18 /usr/local/bin/clang \
    && ln -s /usr/bin/clang++-18 /usr/local/bin/clang++ \
    && rm -rf /var/lib/apt/lists/*

RUN git init /opt/odin && cd /opt/odin \
    && git remote add origin https://github.com/odin-lang/Odin.git \
    && git fetch --depth 1 origin "${ODIN_SOURCE_COMMIT}" \
    && git checkout --detach FETCH_HEAD \
    && LLVM_CONFIG=llvm-config-18 CXX=clang++-18 ./build_odin.sh release \
    && ./odin version

ENV ODIN_ROOT=/opt/odin
ENV PATH="/opt/odin:${PATH}"
WORKDIR /opt/app
COPY src/*.odin ./
RUN odin build . -o:speed -microarch:native -no-bounds-check -out:odin-primes

FROM public.ecr.aws/ubuntu/ubuntu:24.04 AS runtime
WORKDIR /app
COPY --from=build /opt/app/odin-primes ./odin-primes
ENTRYPOINT ["./odin-primes"]
