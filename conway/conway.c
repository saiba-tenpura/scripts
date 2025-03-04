#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <unistd.h>

void clear() {
  printf("\e[1;1H\e[2J");
}

int wrap(int value, int size) {
  if (value < 0) {
    return value + size;
  }

  if (value > size - 1) {
    return value - size;
  }

  return value;
}

int survey(int width, int height, bool state[width][height], int x, int y) {
  int count = 0;
  for (int i = x - 1; i <= x + 1; i++) {
    for (int j = y - 1; j <= y + 1; j++) {
      if (i == x && j == y) {
         continue;
      }

      int index = wrap(i, width);
      int indey = wrap(j, height);
      if (state[index][indey]) {
        count++;
      }
    }
  }

  return count;
}

void simulate(int width, int height, bool state[width][height], bool next_state[width][height]) {
  int count = 0;
  for (int i = 0; i < width; i++) {
    for (int j = 0; j < height; j++) {
      count = survey(width, height, state, i, j);
      if (state[i][j] == true && (count < 2 || count > 3)) {
        next_state[i][j] = false;
      } else if (state[i][j] == false && count == 3) {
        next_state[i][j] = true;
      } else {
        next_state[i][j] = state[i][j];
      }
    }
  }
}

void render(int width, int height, bool state[width][height]) {
  clear();
  for (int i = 0; i < width; i++) {
    for (int j = 0; j < height; j++) {
      printf("%s ", state[i][j] ? "#" : " ");
    }

    printf("\n");
  }
}

int main(int argc, char **argv) {
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

  bool next_state[width][height];
  bool state[width][height];
  memset(state, false, width * height * sizeof(bool));

  state[4][5] = true;
  state[5][4] = true;
  state[5][5] = true;
  state[6][5] = true;
  state[6][6] = true;

  while (true) {
    simulate(width, height, state, next_state);
    render(width, height, state);
    memcpy(state, next_state, sizeof(state));
    usleep(100000);
  }

  return 0;
}
