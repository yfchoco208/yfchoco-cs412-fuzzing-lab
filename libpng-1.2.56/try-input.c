#include <stdio.h>
#include <stdlib.h>

// Test what afl++ does 
int main(int argc, char **argv) {
    if (argc < 2) {
        return 0;
    }

    FILE *fp = fopen(argv[1], "rb");
    if (!fp) {
        return 0;
    }

    char buf[32];
    size_t n = fread(buf, 1, sizeof(buf), fp);
    fclose(fp);

    printf("Input file: %s\n", argv[1]);
    printf("First %zu bytes:\n", n);

    // read the first 32 bytes in hexadecimal 
    for (size_t i = 0; i < n; i++) {
        printf("%02x ", buf[i]);
    }
    printf("\n");

    return 0;
}