#include "tree_sitter/parser.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

enum TokenType {
  INDENT,
  DEDENT,
  NEWLINE,
  COMMENT,
  SPACE,
  TIGHT,
  SHIP,
  DURATION,
};

#define MAX_INDENTS 509u

typedef struct {
  uint16_t *columns;
  uint16_t length;
  uint16_t capacity;
  uint16_t pending_dedents;
  bool newline_pending;
  bool eof_pending;
  bool at_line_start;
  bool started;
  bool finished;
  bool line_has_code;
  bool comment_only;
} Scanner;

static bool reserve(Scanner *scanner, uint16_t needed) {
  if (needed <= scanner->capacity) return true;
  uint16_t capacity = scanner->capacity ? scanner->capacity : 16u;
  while (capacity < needed) {
    if (capacity >= MAX_INDENTS) return false;
    capacity = (uint16_t)(capacity * 2u);
    if (capacity > MAX_INDENTS) capacity = MAX_INDENTS;
  }
  void *columns = realloc(scanner->columns, capacity * sizeof(uint16_t));
  if (!columns) return false;
  scanner->columns = columns;
  scanner->capacity = capacity;
  return true;
}

static bool push(Scanner *scanner, uint16_t column) {
  if (scanner->length >= MAX_INDENTS || !reserve(scanner, scanner->length + 1u)) {
    return false;
  }
  scanner->columns[scanner->length++] = column;
  return true;
}

static void reset(Scanner *scanner) {
  scanner->length = 0;
  scanner->pending_dedents = 0;
  scanner->newline_pending = false;
  scanner->eof_pending = false;
  scanner->at_line_start = true;
  scanner->started = false;
  scanner->finished = false;
  scanner->line_has_code = false;
  scanner->comment_only = false;
  push(scanner, 0);
}

void *tree_sitter_jibb_external_scanner_create(void) {
  Scanner *scanner = calloc(1, sizeof(Scanner));
  if (!scanner) return NULL;
  reset(scanner);
  if (!scanner->columns) {
    free(scanner);
    return NULL;
  }
  return scanner;
}

void tree_sitter_jibb_external_scanner_destroy(void *payload) {
  Scanner *scanner = payload;
  if (!scanner) return;
  free(scanner->columns);
  free(scanner);
}

unsigned tree_sitter_jibb_external_scanner_serialize(void *payload, char *buffer) {
  Scanner *scanner = payload;
  if (!scanner || scanner->length == 0 || scanner->length > MAX_INDENTS) return 0;

  unsigned flags = (scanner->at_line_start ? 1u : 0u) |
                   (scanner->started ? 2u : 0u) |
                   (scanner->finished ? 4u : 0u) |
                   (scanner->line_has_code ? 8u : 0u) |
                   (scanner->newline_pending ? 16u : 0u) |
                   (scanner->eof_pending ? 32u : 0u) |
                   (scanner->comment_only ? 64u : 0u);
  buffer[0] = (char)flags;
  buffer[1] = (char)(scanner->length & 0xffu);
  buffer[2] = (char)(scanner->length >> 8);
  buffer[3] = (char)(scanner->pending_dedents & 0xffu);
  buffer[4] = (char)(scanner->pending_dedents >> 8);
  for (uint16_t i = 0; i < scanner->length; ++i) {
    unsigned at = 5u + 2u * i;
    buffer[at] = (char)(scanner->columns[i] & 0xffu);
    buffer[at + 1u] = (char)(scanner->columns[i] >> 8);
  }
  return 5u + 2u * scanner->length;
}

void tree_sitter_jibb_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {
  Scanner *scanner = payload;
  if (!scanner) return;
  reset(scanner);
  if (!buffer || length < 5u) return;

  uint16_t count = (uint16_t)(unsigned char)buffer[1] |
                   (uint16_t)((uint16_t)(unsigned char)buffer[2] << 8);
  if (count == 0 || count > MAX_INDENTS || length != 5u + 2u * count) return;

  uint16_t *saved = malloc(count * sizeof(uint16_t));
  if (!saved) return;
  for (uint16_t i = 0; i < count; ++i) {
    unsigned at = 5u + 2u * i;
    saved[i] = (uint16_t)(unsigned char)buffer[at] |
               (uint16_t)((uint16_t)(unsigned char)buffer[at + 1u] << 8);
  }
  if (saved[0] != 0 || !reserve(scanner, count)) {
    free(saved);
    return;
  }
  memcpy(scanner->columns, saved, count * sizeof(uint16_t));
  free(saved);
  scanner->length = count;

  unsigned flags = (unsigned char)buffer[0];
  scanner->at_line_start = (flags & 1u) != 0;
  scanner->started = (flags & 2u) != 0;
  scanner->finished = (flags & 4u) != 0;
  scanner->line_has_code = (flags & 8u) != 0;
  scanner->newline_pending = (flags & 16u) != 0;
  scanner->eof_pending = (flags & 32u) != 0;
  scanner->comment_only = (flags & 64u) != 0;
  scanner->pending_dedents = (uint16_t)(unsigned char)buffer[3] |
                             (uint16_t)((uint16_t)(unsigned char)buffer[4] << 8);
}

static bool emit(TSLexer *lexer, enum TokenType symbol) {
  lexer->mark_end(lexer);
  lexer->result_symbol = symbol;
  return true;
}

static bool duration_unit(uint32_t c) {
  return c == 'd' || c == 'h' || c == 'm' || c == 's';
}

static bool duration_text(const char *text) {
  const char *at = text;
  for (;;) {
    if (!duration_unit((unsigned char)*at++)) return false;
    if (*at < '0' || *at > '9') return false;
    while (*at >= '0' && *at <= '9') ++at;
    if (*at == 0) return true;
    if (*at++ != '.') return false;
    if (*at == '.') {
      ++at;
      for (unsigned group = 0; group < 4u; ++group) {
        for (unsigned digit = 0; digit < 4u; ++digit) {
          char c = *at++;
          if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) return false;
        }
        if (*at == 0) return true;
        if (*at++ != '.') return false;
      }
      return false;
    }
  }
}

static bool ship_text(const char *text) {
  const char *at = text;
  unsigned first = 0;
  while (*at >= 'a' && *at <= 'z') {
    ++at;
    ++first;
  }
  if (first != 3u && first != 6u) return false;
  while (*at) {
    if (*at++ != '-') return false;
    for (unsigned letter = 0; letter < 6u; ++letter) {
      if (*at < 'a' || *at > 'z') return false;
      ++at;
    }
  }
  return true;
}

static bool scan_tilde(TSLexer *lexer, const bool *valid_symbols) {
  lexer->advance(lexer, false);
  if (lexer->lookahead < 'a' || lexer->lookahead > 'z') return false;

  char text[128];
  size_t length = 0;
  for (;;) {
    int32_t c = lexer->lookahead;
    bool member = (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '.';
    if (!member) break;
    if (length + 1u >= sizeof(text)) return false;
    text[length++] = (char)c;
    lexer->advance(lexer, false);
  }
  text[length] = 0;

  if (valid_symbols[DURATION] && duration_text(text)) return emit(lexer, DURATION);
  if (valid_symbols[SHIP] && ship_text(text)) return emit(lexer, SHIP);
  return false;
}

static bool finish_file(Scanner *scanner, TSLexer *lexer, const bool *valid_symbols) {
  if (!scanner->started || scanner->finished) return false;

  uint16_t dedents = scanner->length > 0 ? scanner->length - 1u : 0u;
  if (dedents) {
    if (!valid_symbols[DEDENT]) return false;
    scanner->length = 1;
    scanner->pending_dedents = dedents - 1u;
    scanner->newline_pending = true;
    scanner->eof_pending = true;
    scanner->at_line_start = false;
    return emit(lexer, DEDENT);
  }
  if (!valid_symbols[NEWLINE]) return false;
  scanner->finished = true;
  scanner->eof_pending = false;
  scanner->newline_pending = false;
  return emit(lexer, NEWLINE);
}

static bool scan_comment(Scanner *scanner, TSLexer *lexer, const bool *valid_symbols, bool line_start) {
  if (!valid_symbols[COMMENT] || lexer->lookahead != ':') return false;
  lexer->advance(lexer, false);
  if (lexer->lookahead != ':') return false;
  lexer->advance(lexer, false);
  while (lexer->lookahead != '\n' && lexer->lookahead != 0) {
    uint32_t c = (uint32_t)lexer->lookahead;
    if (c == '\t' || c == '\r' || c == 127u || c < 32u) return false;
    lexer->advance(lexer, false);
  }
  scanner->comment_only = line_start;
  if (line_start) {
    scanner->at_line_start = true;
    scanner->line_has_code = false;
  } else {
    scanner->started = true;
    scanner->at_line_start = false;
    scanner->line_has_code = true;
  }
  return emit(lexer, COMMENT);
}

bool tree_sitter_jibb_external_scanner_scan(void *payload, TSLexer *lexer, const bool *valid_symbols) {
  Scanner *scanner = payload;
  if (!scanner || scanner->finished) return false;

  if (scanner->pending_dedents) {
    if (!valid_symbols[DEDENT]) return false;
    --scanner->pending_dedents;
    return emit(lexer, DEDENT);
  }
  if (scanner->newline_pending) {
    if (!valid_symbols[NEWLINE]) return false;
    scanner->newline_pending = false;
    if (scanner->eof_pending) {
      scanner->eof_pending = false;
      scanner->finished = true;
    } else {
      scanner->started = true;
      scanner->line_has_code = true;
      scanner->at_line_start = false;
    }
    return emit(lexer, NEWLINE);
  }

  bool skipped_lines = false;

  if (valid_symbols[SPACE] && lexer->lookahead == ' ') {
    while (lexer->lookahead == ' ') lexer->advance(lexer, false);
    if (lexer->lookahead == ':') return scan_comment(scanner, lexer, valid_symbols, false);
    if (lexer->lookahead == 0) return finish_file(scanner, lexer, valid_symbols);
    if (lexer->lookahead == ')' || lexer->lookahead == ']' || lexer->lookahead == '}') {
      return false;
    }
    if (lexer->lookahead != '\n') return emit(lexer, SPACE);
  }
  if (valid_symbols[TIGHT]) {
    int32_t c = lexer->lookahead;
    if (c != ' ' && c != '\n' && c != 0) return emit(lexer, TIGHT);
    if (c == ' ') return false;
  }
  if ((valid_symbols[SHIP] || valid_symbols[DURATION]) &&
      lexer->lookahead != '\n' && lexer->lookahead != 0) {
    while (lexer->lookahead == ' ') lexer->advance(lexer, true);
    if (lexer->lookahead == '~') return scan_tilde(lexer, valid_symbols);
    return false;
  }

  if (lexer->lookahead == ':') {
    bool line_start = scanner->at_line_start && lexer->get_column(lexer) == 0;
    return scan_comment(scanner, lexer, valid_symbols, line_start);
  }

  if (!scanner->at_line_start || lexer->get_column(lexer) != 0) {
    if (lexer->lookahead == 0) return finish_file(scanner, lexer, valid_symbols);

    while (lexer->lookahead == ' ') lexer->advance(lexer, false);
    if (lexer->lookahead == ':') {
      return scan_comment(scanner, lexer, valid_symbols, false);
    }
    if (lexer->lookahead == 0) return finish_file(scanner, lexer, valid_symbols);

    if (lexer->lookahead != '\n') {
      scanner->started = true;
      scanner->line_has_code = true;
      return false;
    }

    if (scanner->comment_only) {
      lexer->advance(lexer, false);
      skipped_lines = true;
      scanner->comment_only = false;
      scanner->at_line_start = true;
      scanner->line_has_code = false;
    } else {
      if (!(valid_symbols[INDENT] || valid_symbols[DEDENT] || valid_symbols[NEWLINE])) {
        return false;
      }
      lexer->advance(lexer, false);
      skipped_lines = true;
      scanner->started = true;
      scanner->at_line_start = true;
      scanner->line_has_code = false;
    }
  }

  for (;;) {
    while (lexer->lookahead == ' ') lexer->advance(lexer, false);

    if (lexer->lookahead == '\n') {
      lexer->advance(lexer, false);
      skipped_lines = true;
      scanner->comment_only = false;
      continue;
    }
    if (lexer->lookahead == 0) {
      if (!scanner->started && skipped_lines && valid_symbols[NEWLINE]) {
        scanner->finished = true;
        return emit(lexer, NEWLINE);
      }
      return finish_file(scanner, lexer, valid_symbols);
    }
    if (lexer->lookahead == ':') return scan_comment(scanner, lexer, valid_symbols, true);

    uint32_t column = lexer->get_column(lexer);
    if (column > UINT16_MAX) return false;

    scanner->comment_only = false;
    if (!scanner->started) {
      if (column != 0) return emit(lexer, INDENT);
      scanner->started = true;
      scanner->line_has_code = true;
      scanner->at_line_start = false;
      if (skipped_lines && valid_symbols[NEWLINE]) return emit(lexer, NEWLINE);
      return false;
    }

    uint16_t top = scanner->columns[scanner->length - 1u];
    if (column > top) {
      if (!valid_symbols[INDENT] || !push(scanner, (uint16_t)column)) return false;
      scanner->at_line_start = false;
      scanner->line_has_code = true;
      return emit(lexer, INDENT);
    }

    if (column < top) {
      if (!valid_symbols[DEDENT]) return false;
      uint16_t count = 0;
      while (scanner->length > 1u && column < scanner->columns[scanner->length - 1u]) {
        --scanner->length;
        ++count;
      }
      if (column != scanner->columns[scanner->length - 1u]) return false;
      scanner->pending_dedents = count - 1u;
      scanner->newline_pending = true;
      scanner->eof_pending = false;
      scanner->at_line_start = false;
      return emit(lexer, DEDENT);
    }

    if (!valid_symbols[NEWLINE]) return false;
    scanner->at_line_start = false;
    scanner->line_has_code = true;
    return emit(lexer, NEWLINE);
  }
}
