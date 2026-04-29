
# Fuzzing libpng with AFL++ + ASan and QEMU

AFL_CC = afl-clang-fast 
AFL_CXX = afl-clang-fast++ 
QEMU_CC = gcc

MIN_CC = afl-cmin
FUZZ_CC = afl-fuzz

AFL_CFLAGS = -fsanitize=address -g -O1
QEMU_CFLAGS = -g -O1

LDFLAGS = -fsanitize=address
LIBPNG_DIR = libpng-1.2.56

SRCS = harness.c

AFL_TARGET = png_fuzz
QEMU_TARGET = png_fuzz_qemu

AFL_INCDIR = -I$(LIBPNG_DIR)/install/include
AFL_LIBDIR = -L$(LIBPNG_DIR)/install/lib

QEMU_INCDIR = -I$(LIBPNG_DIR)/install_vanilla/include
QEMU_LIBDIR = -L$(LIBPNG_DIR)/install_vanilla/lib

AFL_FUZZ_OUT = findings-test
# AFL_FUZZ_OUT = findings
QEMU_FUZZ_OUT = findings-qemu-test
# QEMU_FUZZ_OUT = findings-qemu
EXTRAS = -lpng12 -lz -lm

# libpng might be a directory so call PHONY
.PHONY: libpng-afl libpng-qemu harness-afl harness-qemu fuzz-afl fuzz-qemu clean build #min

# Build libpng as static library with AFL++ and ASan
libpng-afl:
	cd $(LIBPNG_DIR) && make distclean || true
	cd $(LIBPNG_DIR) && \
	CC=$(AFL_CC) CXX=$(AFL_CXX) \
	CFLAGS="$(AFL_CFLAGS)" \
	LDFLAGS="$(LDFLAGS)" \
	./configure --disable-shared --prefix=$$(pwd)/install &&\
	make -j$$(nproc) && make install

libpng-qemu:
	cd $(LIBPNG_DIR) && make distclean || true
	cd $(LIBPNG_DIR) && \
	CC=$(QEMU_CC) \
	CFLAGS="$(QEMU_CFLAGS)" \
	./configure --disable-shared --prefix=$$(pwd)/install_vanilla &&\
	make -j$$(nproc) && make install

# Compile harness and start fuzz (& minimize corpus)
harness-afl:
	$(AFL_CC) $(SRCS) $(AFL_INCDIR) $(AFL_LIBDIR) $(EXTRAS) $(AFL_CFLAGS) -o $(AFL_TARGET)

harness-qemu:
	$(QEMU_CC) $(SRCS) $(QEMU_INCDIR) $(QEMU_LIBDIR) $(EXTRAS) $(QEMU_CFLAGS) -o $(QEMU_TARGET)

# Already minimized and provided as seed
# min: 
# $(MIN_CC) -i $(LIBPNG_DIR)/seeds_original/ -o minimized/ -- ./$(TARGET_H) @@

fuzz-afl:
	$(FUZZ_CC) -i seeds -o $(AFL_FUZZ_OUT) -x png.dict -- ./$(AFL_TARGET) @@

fuzz-qemu:
	$(FUZZ_CC) -Q -i seeds -o $(QEMU_FUZZ_OUT) -x png.dict -- ./$(QEMU_TARGET) @@

clean:
	rm -f $(AFL_TARGET) $(QEMU_TARGET)

# build, run/fuzz, clean required as mentioned in handout
build: libpng-afl harness-afl libpng-qemu harness-qemu
fuzz: fuzz-afl
