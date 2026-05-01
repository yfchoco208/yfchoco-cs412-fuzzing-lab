
# Fuzzing libpng with AFL++ + ASan and QEMU (and AFL++ + NO ASan)

AFL_CC = afl-clang-fast 
AFL_CXX = afl-clang-fast++ 
QEMU_CC = gcc

MIN_CC = afl-cmin
FUZZ_CC = afl-fuzz

AFL_CFLAGS = -fsanitize=address -g -O1
QEMU_CFLAGS = -g -O1

LDFLAGS = -fsanitize=address
#LIBPNG_DIR = libpng-1.2.56
LIBPNG_DIR = libpng-1.2.53

SRCS = harness.c
SRCS_PER = harness_persistent.c

AFL_TARGET = png_fuzz
QEMU_TARGET = png_fuzz_qemu
AFL_PER_TARGET = png_fuzz_persistent

#SEEDS_DIR = seeds
SEEDS_DIR = seeds_relevant

AFL_INCDIR = -I$(LIBPNG_DIR)/install/include
AFL_LIBDIR = -L$(LIBPNG_DIR)/install/lib

QEMU_INCDIR = -I$(LIBPNG_DIR)/install_vanilla/include
QEMU_LIBDIR = -L$(LIBPNG_DIR)/install_vanilla/lib

#AFL_FUZZ_OUT = findings-test
AFL_FUZZ_OUT = findings
#QEMU_FUZZ_OUT = findings-qemu-test
QEMU_FUZZ_OUT = findings-qemu
#AFL_PER_FUZZ_OUT = findings-per-test
AFL_PER_FUZZ_OUT = findings-per

EXTRAS = -lpng12 -lz -lm

# Fuzzing with AFL++ and NO ASan 
AFL_NO_TARGET = png_fuzz_no
AFL_NO_FUZZ_OUT = findings-no-test
# AFL_NO_FUZZ_OUT = findings-no
AFL_NO_CFLAGS = -g -O1
AFL_NO_INCDIR = -I$(LIBPNG_DIR)/install_no/include
AFL_NO_LIBDIR = -L$(LIBPNG_DIR)/install_no/lib



# libpng might be a directory so call PHONY
.PHONY: libpng-afl libpng-qemu harness-afl harness-qemu fuzz-afl fuzz-qemu \
harness-afl-per fuzz-afl-per libpng-afl-no harness-afl-no fuzz-afl-no \
clean-test build fuzz clean #min

# Build libpng as static library with AFL++ and ASan
libpng-afl:
	cd $(LIBPNG_DIR) && make distclean || true
	cd $(LIBPNG_DIR) && rm -rf install
	cd $(LIBPNG_DIR) && \
	CC=$(AFL_CC) CXX=$(AFL_CXX) \
	CFLAGS="$(AFL_CFLAGS)" \
	LDFLAGS="$(LDFLAGS)" \
	./configure --disable-shared --prefix=$$(pwd)/install &&\
	make -j$$(nproc) && make install

libpng-qemu:
	cd $(LIBPNG_DIR) && make distclean || true
	cd $(LIBPNG_DIR) && rm -rf install_vanilla
	cd $(LIBPNG_DIR) && \
	CC=$(QEMU_CC) \
	CFLAGS="$(QEMU_CFLAGS)" \
	./configure --disable-shared --prefix=$$(pwd)/install_vanilla &&\
	make -j$$(nproc) && make install

libpng-afl-no:
	cd $(LIBPNG_DIR) && make distclean || true
	cd $(LIBPNG_DIR) && rm -rf install_no
	cd $(LIBPNG_DIR) && \
	CC=$(AFL_CC) CXX=$(AFL_CXX) \
	CFLAGS="$(AFL_NO_CFLAGS)" \
	./configure --disable-shared --prefix=$$(pwd)/install_no &&\
	make -j$$(nproc) && make install

# Compile harness and start fuzz (& minimize corpus)
harness-afl:
	$(AFL_CC) $(SRCS) $(AFL_INCDIR) $(AFL_LIBDIR) $(EXTRAS) $(AFL_CFLAGS) -o $(AFL_TARGET)

harness-qemu:
	$(QEMU_CC) $(SRCS) $(QEMU_INCDIR) $(QEMU_LIBDIR) $(EXTRAS) $(QEMU_CFLAGS) -o $(QEMU_TARGET)

harness-afl-per:
	$(AFL_CC) $(SRCS_PER) $(AFL_INCDIR) $(AFL_LIBDIR) $(EXTRAS) $(AFL_CFLAGS) -o $(AFL_PER_TARGET)

harness-afl-no:
	$(AFL_CC) $(SRCS) $(AFL_NO_INCDIR) $(AFL_NO_LIBDIR) $(EXTRAS) $(AFL_NO_CFLAGS) -o $(AFL_NO_TARGET)

# Already minimized and provided as seed
# min: 
# $(MIN_CC) -i $(LIBPNG_DIR)/seeds_original/ -o minimized/ -- ./$(TARGET_H) @@

fuzz-afl:
	$(FUZZ_CC) -i $(SEEDS_DIR) -o $(AFL_FUZZ_OUT) -x png.dict -- ./$(AFL_TARGET) @@

fuzz-qemu:
	$(FUZZ_CC) -Q -i $(SEEDS_DIR) -o $(QEMU_FUZZ_OUT) -x png.dict -- ./$(QEMU_TARGET) @@

fuzz-afl-per:
	$(FUZZ_CC) -i $(SEEDS_DIR) -o $(AFL_PER_FUZZ_OUT) -x png.dict -- ./$(AFL_PER_TARGET)

fuzz-afl-no:
	$(FUZZ_CC) -i $(SEEDS_DIR) -o $(AFL_NO_FUZZ_OUT) -x png.dict -- ./$(AFL_NO_TARGET) @@

clean:
	rm -f $(AFL_TARGET) $(QEMU_TARGET) $(AFL_PER_TARGET) $(AFL_NO_TARGET)

clean-test:
	rm -rf findings-test findings-qemu-test findings-per-test findings-no-test

# build, run/fuzz, clean required as mentioned in handout
build: libpng-afl harness-afl libpng-qemu harness-qemu harness-afl-per \
libpng-afl-no harness-afl-no
fuzz: fuzz-afl
