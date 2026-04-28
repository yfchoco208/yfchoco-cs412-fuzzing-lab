#include "png.h"
#include "stdio.h"
#include "stdlib.h"
#include "stdint.h"
#include "stdbool.h"

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

    printf("Input file: %s\n", argv[1]);
    printf("First %zu bytes:\n", n);

    // read the first 32 bytes in hexadecimal 
    for (size_t i = 0; i < n; i++) {
        printf("%02x ", buf[i]);
    }
    printf("\n");

    /* Create structs */
    png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    if (!png) {
        fclose(fp);
        return 0;
    }

    png_infop info = png_create_info_struct(png);
    if (!info) {
        fclose(fp);
        png_destroy_read_struct(&png, NULL, NULL);
        return 0;
    }
    rewind(fp);
    png_init_io(png, fp);
    png_read_info(png, info);

    png_uint_32 width;
    png_uint_32 height;
    int bit_depth;
    int color_type;

    png_get_IHDR(png, info, &width, &height, &bit_depth, &color_type, NULL, NULL, NULL);

    printf("Width: %ld\n", width);
    printf("Height: %ld\n", height);

    fclose(fp);
    return 0;
}