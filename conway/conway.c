#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>

struct Field {
  int width;
  int height;
  bool state[];
};

struct Field *init(int width, int height)
{
  struct Field *field = malloc(sizeof(struct Field*) + width * height * sizeof(bool));
  if (field == NULL) {
    printf("Failed to allocate memory for field!");
    exit(EXIT_FAILURE);
  }

  field->width = width;
  field->height = height;
  memset(field->state, false, width * height * sizeof(bool));
  return field;
}

int wrap(int value, int size)
{
  if (value < 0) {
    return value + size;
  }

  if (value > size - 1) {
    return value - size;
  }

  return value;
}

int survey(struct Field *field, int x, int y)
{
  int count = 0;
  for (int i = x - 1; i <= x + 1; i++) {
    for (int j = y - 1; j <= y + 1; j++) {
      if (i == x && j == y) {
         continue;
      }

      int index = wrap(i, field->width);
      int indey = wrap(j, field->height);
      if (field->state[index * field->width + indey]) {
        count++;
      }
    }
  }

  return count;
}

void simulate(struct Field *field, bool next_state[field->width][field->height])
{
  int count = 0;
  for (int i = 0; i < field->width; i++) {
    for (int j = 0; j < field->height; j++) {
      count = survey(field, i, j);
      if (field->state[i * field->width + j] == true && (count < 2 || count > 3)) {
        next_state[i][j] = false;
      } else if (field->state[i * field->width + j] == false && count == 3) {
        next_state[i][j] = true;
      } else {
        next_state[i][j] = field->state[i * field->width + j];
      }
    }
  }
}

void clear()
{
  printf("\e[1;1H\e[2J");
}

void render(struct Field *field)
{
  clear();
  for (int i = 0; i < field->width; i++) {
    for (int j = 0; j < field->height; j++) {
      printf("%s ", field->state[i * field->width + j] ? "#" : " ");
    }

    printf("\n");
  }
}

int main(int argc, char **argv)
{
  int opt;
  int width, height;
  width = height = 15;
  static struct option long_options[] = {
    {"width", required_argument, NULL, 'w'},
    {"height", required_argument, NULL, 'h'},
    {NULL, 0, NULL, 0},
  };

  while ((opt = getopt_long(argc, argv, "w:h:", long_options, NULL)) != -1) {
    switch (opt) {
      case 'w':
        width = strtol(optarg, NULL, 10);
        break;
      case 'h':
        height = strtol(optarg, NULL, 10);
        break;
    }
  }

  struct Field *field = init(width, height);
  bool next_state[width][height];
  field->state[4 * width + 5] = true;
  field->state[5 * width + 4] = true;
  field->state[5 * width + 5] = true;
  field->state[6 * width + 5] = true;
  field->state[6 * width + 6] = true;

  while (true) {
    simulate(field, next_state);
    render(field);
    memcpy(field->state, next_state, width * height * sizeof(bool));
    usleep(100000);
  }

  free(field);
  return 0;
}
