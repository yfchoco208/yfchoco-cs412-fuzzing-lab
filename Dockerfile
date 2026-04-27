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
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/AFLplusplus/AFLplusplus.git /opt/AFLplusplus && \
    cd /opt/AFLplusplus && \
    make distrib && \
    make install

WORKDIR /fuzzing