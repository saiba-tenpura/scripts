#ifndef CONWAY_H
#define CONWAY_H

#include <stdbool.h>

struct Field {
  int width;
  int height;
  bool state[];
};

struct Field *init(int width, int height);

void set(struct Field *field, int width, int height, bool pattern[width][height], int offset_x, int offset_y);
void simulate(struct Field *field, bool next_state[field->width][field->height]);
void render(struct Field *field);
void clear();

int survey(struct Field *field, int x, int y);
int wrap(int value, int size);

#endif /* CONWAY_H */
