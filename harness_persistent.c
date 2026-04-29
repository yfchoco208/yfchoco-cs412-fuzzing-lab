#include <png.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include <setjmp.h>

#define MAX_PIXEL (2048u * 2048u)

__AFL_FUZZ_INIT();

/* 
Struct for callback:
Contain the data (buf), size (len), and offset 0
*/
typedef struct {
    const unsigned char * data; 
    size_t size; /*AFL++ input buff size */
    size_t offset; /* Read position, just like for file*/
} dataStorage;

/* 
Callback function
Handle AFL++ input just like File, read passed bytes and move offset
Copy length bytes into libpng's buffer (data)
*/
static void read_callback(png_structp png, png_bytep libbuf, png_size_t length) {
    dataStorage *ds = (dataStorage *)png_get_io_ptr(png);
    size_t remaining = ds->size - ds->offset;
    if (remaining < length) {
        png_error(png, "Invalid length");
        return;
    }
    /* Write bytes */
    for (png_size_t i = 0; i < length; i++) {
        libbuf[i] = ds->data[ds->offset + i];
    }
    /* Move head (offset) */
    ds->offset += length;
}

bool png_too_big(png_uint_32 width, png_uint_32 height) {
    /* Ensure it doesn't overflow */
    if (width != 0 && height > MAX_PIXEL / width) {
        return true;
    }

    return false;
}

int main(int argc, char **argv) {
    __AFL_INIT(); /* deferred fork server */
    unsigned char *buf = __AFL_FUZZ_TESTCASE_BUF;


    while (__AFL_LOOP(10000)) {
        int len = __AFL_FUZZ_TESTCASE_LEN;

        if (len <= 0) {
            continue;
        }
        /* 
        Create structs inside loop so it avoids state leakage 
        */
        png_structp png = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
        if (!png) {
            continue; /* continue instead of return since inside loop */
        }

        png_infop info = png_create_info_struct(png);
        if (!info) {
            png_destroy_read_struct(&png, NULL, NULL);
            continue;
        }

        /* Catch errors using setjmp handler */
        if (setjmp(png_jmpbuf(png))) {
            png_destroy_read_struct(&png, &info, NULL);
            continue;
        }

        dataStorage ds;
        ds.data = buf;
        ds.size = (size_t)len;
        ds.offset = 0;

        png_set_read_fn(png, &ds, read_callback);


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
            png_destroy_read_struct(&png, &info, NULL);
            continue;
        }
        if (png_too_big(width, height)){
            png_destroy_read_struct(&png, &info, NULL);
            continue;
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
            png_destroy_read_struct(&png, &info, NULL);
            continue;
        }

        png_bytep *row_pointers = malloc(sizeof(png_bytep) * height);
        bool row_alloc_fail = false;
        
        if (!row_pointers) {
            png_destroy_read_struct(&png, &info, NULL);
            continue;
        }

        for (uint32_t i = 0; i < height; i++) {
            /* Allocate for each row */ 
            row_pointers[i] = malloc(bytes_per_row);
            if (!row_pointers[i]) {
                for (uint32_t j = 0; j < i; j++) {
                    /* Free all previous rows*/
                    free(row_pointers[j]);
                }
                free(row_pointers);
                png_destroy_read_struct(&png, &info, NULL);
                row_alloc_fail = true;
                break;
            }
        }
        if (row_alloc_fail) {
            continue;
        }

        png_read_image(png, row_pointers);

        /* Read post-IDAT */
        png_read_end(png, NULL);

        /* Clean up*/
        for (png_uint_32 i = 0; i < height; i++) {
            free(row_pointers[i]);
        }
        free(row_pointers);
        png_destroy_read_struct(&png, &info, NULL);
        continue;
    }
    return 0;
}