FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    make \
    wget \
	patch \
    tar \
    git \
	qemu-user \
    zlib1g-dev \
    gnuplot \
	pkg-config \
    libglib2.0-dev \
    libpixman-1-dev \
    ninja-build \
    python3 \
	meson \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/AFLplusplus/AFLplusplus.git /opt/AFLplusplus && \
    cd /opt/AFLplusplus && \
    make distrib && \
    cd qemu_mode && \
    ./build_qemu_support.sh && \
    cd .. && \
    make install

WORKDIR /fuzzing