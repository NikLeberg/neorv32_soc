/**
 * C program to generate LUT values for FPGA rom initialization. Writes data to
 * lut_pkg.vhdl file.
 *
 * Compile with: gcc generator.c -lm -o generator
 * Generate LUT with: ./generator
 */

#include <stdio.h>
#include <string.h>
#include <math.h>

const char *fileName = "lut_sin_pkg.vhdl";
const char *startLine = "    CONSTANT c_lut_sin : lut_sin_type := (";
const char *endLine = "    );";
const int nBitsAddress = 12;
const int nBitsValue = 10;

// Function source: Moodle - Theo Kluter.
void printBits(FILE *f, int value, int nBits)
{
    int mask = 1 << (nBits - 1);
    while (mask != 0)
    {
        if ((value & mask) == mask)
            fprintf(f, "1");
        else
            fprintf(f, "0");
        mask >>= 1;
    }
}

int main()
{
    FILE *fPtr;
    FILE *fTemp;

    fPtr = fopen(fileName, "r");
    fTemp = fopen("temp.tmp", "w");

    /* fopen() return NULL if unable to open file in given mode. */
    if (fPtr == NULL || fTemp == NULL)
    {
        /* Unable to open file hence exit */
        printf("\nUnable to open file.\n");
        printf("Please check whether file exists and you have read/write privilege.\n");
        return 0;
    }

    /*
     * Read line by line. When startLine is reached, start to generate data.
     * After the generated data the rest of the file is copied unchanged.
     */
    char *line = NULL;
    size_t len = 0;
    ssize_t read;

    /*
     * Read file line by line until startLine is reached.
     */
    while ((read = getline(&line, &len, fPtr)) != -1)
    {
        fputs(line, fTemp);
        if (strstr(line, startLine) != 0)
        {
            break;
        }
    }

    /*
     * Skip over all lines until endLine is reached.
     */
    while ((read = getline(&line, &len, fPtr)) != -1)
    {
        if (strstr(line, endLine) != 0)
        {
            break;
        }
    }

    /*
     * Generate sine wave LUT in range [0 2*pi] with a resolution of 10 bits.
     */
    int maxValue = powf(2.0f, nBitsValue);
    int maxAddress = powf(2.0f, nBitsAddress);
    for (int n = 0; n < maxAddress; ++n)
    {
        fputs("        \"", fTemp);
        float sinValF = 0.5f * (sinf(n * 2.0f * M_PI / maxAddress) + 1.0f);
        int sinValI = sinValF * (maxValue - 1);
        printBits(fTemp, sinValI, 10);
        if (n != (maxAddress - 1))
        {
            fputs("\",\n", fTemp);
        }
        else
        {
            fputs("\"\n", fTemp);
        }
    }

    /*
     * Write endLine and copy rest of file.
     */
    fputs(line, fTemp);
    while ((read = getline(&line, &len, fPtr)) != -1)
    {
        fputs(line, fTemp);
    }

    /* Delete original source file */
    remove(fileName);

    /* Rename temp file as original file */
    rename("temp.tmp", fileName);

    puts("\nSuccessfully generated sine wave LUT.");

    return 0;
}
