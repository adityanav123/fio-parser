#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <fnmatch.h>
#include <errno.h>
#include <unistd.h>

int progress(int current, int total) {
    char bar[52];
    int len = (int)(((double)current / total) * 50);
    memset(bar, '#', len);
    memset(bar + len, '.', 50 - len);
    bar[50] = '\0';
    printf("\r[%s] %d%%", bar, (int)(((double)current / total) * 100));
    fflush(stdout);
    return 0;
}

char *remove_ext(char *file_name) {
    char *dot = strrchr(file_name, '.');
    if (!dot || dot == file_name) return file_name;
    *dot = '\0';
    return file_name;
}

typedef struct FioParse {
    int parsedValue;
    char *fileName;
} fio_parse_t;

int parse_fio(char **files, int count, const char *operation, fio_parse_t *results) {
    if (!operation || !files || count <= 0) {
        return 0;
    }
    int result_count = 0;

    // printf("Parsing %d files for operation: %s\n", count, operation);
    // printf("Files: ");
    // for (int i = 0; i < count; ++i) {
    //     printf("%s ", files[i]);
    // }
    // printf("\n");

    for (int i = 0; i < count; ++i) {
        // printf("Processing file %d/%d: %s\n", i + 1, count, files[i]);
        char *file = files[i];
        FILE *fp = fopen(file, "r");
        if (!fp) {
            fprintf(stderr, "Error opening file '%s': %s\n", file, strerror(errno));
            continue;
        }

        char *toSearch = (operation && strcmp(operation, "write") == 0) ? "WRITE:" : "READ:";

        char line[500];
        while (fgets(line, sizeof(line), fp)) {
            int num;
            char unit[16];
            // printf("<debug> line: %s\n", line);
            if (sscanf(line, "%*[^b]bw=%*[^()] (%d%15[^)])", &num, unit) == 2) {
                fio_parse_t *parsed = malloc(sizeof(fio_parse_t));
                parsed->parsedValue = num;
                parsed->fileName = strdup(file);
                results[result_count++] = *parsed;
                free(parsed);
            }
        }
        
        fclose(fp);
    }
    return result_count;
}


int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "USAGE: %s <read|write> <file1> [file2] ...\n", argv[0]);
        fprintf(stderr, "Example: %s read fio_read_200MB.log fio_read.log fio_read_300MB.log fio_read_2G.log\n", argv[0]);
        return 1;
    }

    char *operation = argv[1];
    if (strcmp(operation, "read") != 0 && strcmp(operation, "write") != 0) {
        fprintf(stderr, "USAGE: %s <read|write> <file1> [file2] ...\n", argv[0]);
        fprintf(stderr, "Example: %s read fio_read_200MB.log fio_read.log fio_read_300MB.log fio_read_2G.log\n", argv[0]);
        return 1;
    }

    char **files_to_parse = &argv[2];
    size_t files_count = argc - 2;

 
    fio_parse_t *results = (fio_parse_t *)malloc(sizeof(fio_parse_t) * files_count);
    if (!results) {
        fprintf(stderr, "Error allocating memory %s\n", strerror(errno));
        return 1;
    }

    int count = parse_fio(files_to_parse, files_count, operation, results);
    printf("\nParsed %zu files\n", files_count);
    printf("Files: \n");
    for (int i = 0; i < files_count; i++) {
        printf("  %s\n", files_to_parse[i]);
    }
    printf("\nWriting to results.csv...\n");

    FILE *csv_file = fopen("results.csv", "w");
    if (csv_file) {
        for (int i = 0; i < files_count; i++) {
            fprintf(csv_file, "bw_%s%s", remove_ext(results[i].fileName), (i == count - 1) ? "" : ",");
            // printf("bw%d%s", i + 1, (i == count - 1) ? "" : ",");
        }
        fprintf(csv_file, "\n");
        // printf("\n");

        int iterations = count / files_count;
        for (int i = 0; i < iterations; ++i) {
            for (int file_idx = 0; file_idx < files_count; ++file_idx) {
                int idx = i * files_count + file_idx;
                if (idx < count) {
                    fprintf(csv_file, "%d%s", results[idx].parsedValue, (file_idx == files_count - 1) ? "" : ",");
                    // printf("%d%s", results[idx].parsedValue, (file_idx == files_count - 1) ? "" : ",");
                }
            }
            if (i < iterations - 1) {
                fprintf(csv_file, "\n");
                // printf("\n");
            }
        }
        fclose(csv_file);
    } else {
        fprintf(stderr, "Error creating CSV file: %s\n", strerror(errno));
    }
    printf("\nData Written to results.csv\n");

    free(results);
    return 0;
}
