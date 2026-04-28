#include "png.h"
#include "stdio.h"
#include "stdlib.h"
#include "stdint.h"
#include "stdbool.h"
#include "setjmp.h"

#define MAX_PIXEL (2048 * 2048)

bool png_too_big(png_uint_32 width, png_uint_32 height) {
    /* Ensure it doesn't overflow */
    if (width != 0 && height > MAX_PIXEL / width) {
        return true;
    }

    return false;
}

int main(int argc, char **argv) {

    if (argc < 2) {
        return 0;
    }

    /* Read from argv[1] (afl++) */
    FILE *fp = fopen(argv[1], "rb");
    if (!fp) {
        return 0;
    }

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


    /* Catch errors using setjmp handler */
    if (setjmp(png_jmpbuf(png))) {
        fclose(fp);
        png_destroy_read_struct(&png, &info, NULL);
        return 0;
    }


    /*
    Setup AFL++ input to libpng
    Rewind fp before init
    */ 
    rewind(fp);
    png_init_io(png, fp);

    /*
    Feed instrumented input into library function
    Enable more png_set_* to explore more interesting functions
    */
    png_read_info(png, info);

    /*
    Extract height, width, etc from png_get_IHDR(・)
    Add guard on input ex. avoid massive input
    */
    png_uint_32 width;
    png_uint_32 height;
    int bit_depth;
    int color_type;

    png_get_IHDR(png, info, &width, &height, &bit_depth, &color_type, NULL, NULL, NULL);

    /* Check dimention */
    if (width == 0 || height == 0) {
        fclose(fp);
        png_destroy_read_struct(&png, &info, NULL);
        return 0;
    }
    if (png_too_big(width, height)){
        fclose(fp);
        png_destroy_read_struct(&png, &info, NULL);
        return 0;
    }

    /* Apply transformation */
    png_set_expand(png); /* palette -> RGB */
    png_set_strip_16(png); /* 16-bit -> 8-bit */
    png_set_gray_to_rgb(png); /* grayscale -> RGB */
    png_read_update_info(png, info);

    /*
    Initialize array of row pointers (len height):
    */
    png_size_t bytes_per_row = png_get_rowbytes(png, info);
    if (!bytes_per_row) {
        fclose(fp);
        png_destroy_read_struct(&png, &info, NULL);
        return 0;
    }

    /* 
    Intentionally put a bug so it crashes for some input
    malloc(sizeof(png_bytep) * (height)-1) to create off-by-one in row_pointer 
    => for the last row (row height) it crashes
    Make it conditioned on the height value and color type, if the height is above threshold, 
    make it allocate less (try to minimize allocation)
    */
    png_bytep *row_pointers = NULL;

    if (height > 300 && color_type == 4) {
        row_pointers = malloc(sizeof(png_bytep) * (height-1));
    }
    else {
        row_pointers = malloc(sizeof(png_bytep) * height);
    }
    
    if (!row_pointers) {
        fclose(fp);
        png_destroy_read_struct(&png, &info, NULL);
        return 0;
    }

    for (uint32_t i = 0; i < height; i++) {
        /* Allocate for each row */ 
        row_pointers[i] = malloc(bytes_per_row);
        if (!row_pointers[i]) {
            for (uint32_t j = 0; j < i; j++) {
                /* Free all previous rows*/
                free(row_pointers[j]);
            }
            fclose(fp);
            free(row_pointers);
            png_destroy_read_struct(&png, &info, NULL);
            return 0;
        }
    }

    png_read_image(png, row_pointers);

    /* Read post-IDAT */
    png_read_end(png, NULL);

    /* Clean up*/
    for (png_uint_32 i = 0; i < height; i++) {
        free(row_pointers[i]);
    }
    free(row_pointers);
    fclose(fp);
    png_destroy_read_struct(&png, &info, NULL);
    return 0;
}