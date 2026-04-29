
# White box Fuzzing with AFL++ and ASan

CC = afl-clang-fast 
CXX = afl-clang-fast++ 
MIN_CC = afl-cmin
FUZZ_CC = afl-fuzz

CFLAGS = -fsanitize=address -g -O1
LDFLAGS = -fsanitize=address
LIBPNG_DIR = libpng-1.2.56

SRCS_H = harness.c
TARGET_H = png_fuzz
INCDIR_H = -I$(LIBPNG_DIR)/install/include
LIBDIR_H = -L$(LIBPNG_DIR)/install/lib
FUZZ_OUT = findings-test
#FUZZ_OUT = findings
EXTRAS_H = -lpng12 -lz -lm

# libpng might be a directory so call PHONY
.PHONY: libpng harness fuzz clean #min

# Build libpng as static library with AFL++ and ASan
libpng:
	cd $(LIBPNG_DIR) && \
	CC=$(CC) CXX=$(CXX) \
	CFLAGS="$(CFLAGS)" \
	LDFLAGS="$(LDFLAGS)" \
	./configure --disable-shared --prefix=$$(pwd)/install &&\
	make -j$$(nproc) && make install

# Compile harness and start fuzz (& minimize corpus)
harness:
	$(CC) $(SRCS_H) $(INCDIR_H) $(LIBDIR_H) $(EXTRAS_H) $(CFLAGS) -o $(TARGET_H)

# Already minimized and provided as seed
# min: 
# $(MIN_CC) -i $(LIBPNG_DIR)/seeds_original/ -o minimized/ -- ./$(TARGET_H) @@

fuzz:
	$(FUZZ_CC) -i seeds -o $(FUZZ_OUT) -x png.dict -- ./$(TARGET_H) @@

clean:
	rm -f $(TARGET_H)