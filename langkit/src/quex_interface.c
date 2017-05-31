
/*----------------------------------------------------------------------------
--                                                                          --
--                            GPR PROJECT PARSER                            --
--                                                                          --
--            Copyright (C) 2015-2017, Free Software Foundation, Inc.       --
--                                                                          --
-- This library is free software;  you can redistribute it and/or modify it --
-- under terms of the  GNU General Public License  as published by the Free --
-- Software  Foundation;  either version 3,  or (at your  option) any later --
-- version. This library is distributed in the hope that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE.                            --
--                                                                          --
-- As a special exception under Section 7 of GPL version 3, you are granted --
-- additional permissions described in the GCC Runtime Library Exception,   --
-- version 3.1, as published by the Free Software Foundation.               --
--                                                                          --
-- You should have received a copy of the GNU General Public License and    --
-- a copy of the GCC Runtime Library Exception along with this program;     --
-- see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see    --
-- <http://www.gnu.org/licenses/>.                                          --
--                                                                          --
----------------------------------------------------------------------------*/

/*  DO NOT EDIT THIS IS AN AUTOGENERATED FILE */


#include <stdlib.h>

#include "quex_interface.h"
#include "quex_lexer.h"

struct Lexer {
  QUEX_TYPE_ANALYZER quex_lexer;
  void *buffer;
  quex_Token buffer_tk;
};

static void init_lexer(Lexer *lexer) {
  QUEX_NAME(token_p_set)(&lexer->quex_lexer, &lexer->buffer_tk);
  memset(&lexer->buffer_tk, 0, sizeof(lexer->buffer_tk));
}

Lexer *gpr_lexer_from_buffer(uint32_t *buffer, size_t length) {
  Lexer *lexer = malloc(sizeof(Lexer));
  /* Quex requires the following buffer layout:

       * characters 0 and 1: null;
       * characters 2 to LENGTH + 1: the actual content to lex;
       * character LENGHT + 2: null.

     And address to pass must be one character past the address of the
     buffer.  Remember that characters are 4 bytes long (this is handled
     thanks to pointer arithmetic).  */
  QUEX_NAME(construct_memory)
  (&lexer->quex_lexer, buffer + 1, 0, buffer + length + 2, NULL, false);
  init_lexer(lexer);
  return lexer;
}

void gpr_free_lexer(Lexer *lexer) {
  QUEX_NAME(destruct)(&lexer->quex_lexer);
  free(lexer);
}

int gpr_next_token(Lexer *lexer, struct token *tok) {
  /* Some lexers need to keep track of the last token: give them this
     information.  */
  lexer->buffer_tk.last_id = lexer->buffer_tk._id;
  QUEX_NAME(receive)(&lexer->quex_lexer);

  tok->id = lexer->buffer_tk._id;
  tok->text = lexer->buffer_tk.text;
  tok->text_length = lexer->buffer_tk.len;
  tok->start_line = lexer->buffer_tk._line_n;
  tok->end_line = lexer->buffer_tk.end_line;
  tok->start_column = lexer->buffer_tk._column_n;
  tok->end_column = lexer->buffer_tk.end_column;
  tok->offset = lexer->buffer_tk.offset;

  return tok->id != 0;
}
