#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <unistd.h>

#define SIZE 30

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

int survey(bool state[SIZE][SIZE], int x, int y) {
  int count = 0;
  for (int i = x - 1; i <= x + 1; i++) {
    for (int j = y - 1; j <= y + 1; j++) {
      if (i == x && j == y) {
         continue;
      }

      int index = wrap(i, SIZE);
      int indey = wrap(j, SIZE);
      if (state[index][indey]) {
        count++;
      }
    }
  }

  return count;
}

void simulate(bool next_state[SIZE][SIZE], bool state[SIZE][SIZE]) {
  int count = 0;
  for (int i = 0; i < SIZE; i++) {
    for (int j = 0; j < SIZE; j++) {
      count = survey(state, i, j);
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

void render(bool state[SIZE][SIZE]) {
  clear();
  for (int i = 0; i < SIZE; i++) {
    for (int j = 0; j < SIZE; j++) {
      printf("%s ", state[i][j] ? "#" : " ");
    }

    printf("\n");
  }
}

int main() {
  bool next_state[SIZE][SIZE];
  bool state[SIZE][SIZE] = {false};

  state[4][5] = true;
  state[5][4] = true;
  state[5][5] = true;
  state[6][5] = true;
  state[6][6] = true;

  while (true) {
    simulate(next_state, state);
    render(state);
    memcpy(state, next_state, sizeof(state));
    usleep(100000);
  }

  return 0;
}
