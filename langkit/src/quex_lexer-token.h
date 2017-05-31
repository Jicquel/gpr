
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

/* -*- C++ -*-   vim: set syntax=cpp: 
 * (C) 2004-2009 Frank-Rene Schaefer
 * ABSOLUTELY NO WARRANTY
 */
#ifndef __QUEX_INCLUDE_GUARD__TOKEN__GENERATED__QUEX___TOKEN
#define __QUEX_INCLUDE_GUARD__TOKEN__GENERATED__QUEX___TOKEN

/* For '--token-class-only' the following option may not come directly
 * from the configuration file.                                        */
#ifndef    __QUEX_OPTION_PLAIN_C
#   define __QUEX_OPTION_PLAIN_C
#endif
#include <quex/code_base/definitions>
#include <quex/code_base/asserts>
#include <quex/code_base/compatibility/stdint.h>
#include <quex/code_base/MemoryManager>

/* LexemeNull object may be used for 'take_text'. */
QUEX_NAMESPACE_LEXEME_NULL_OPEN
extern QUEX_TYPE_CHARACTER   QUEX_LEXEME_NULL_IN_ITS_NAMESPACE;
QUEX_NAMESPACE_LEXEME_NULL_CLOSE



#   line 8 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"


    /* Redefine the stamp action to add the end line and end column to tokens */
    #undef QUEX_ACTION_TOKEN_STAMP
     #define QUEX_ACTION_TOKEN_STAMP(TOKEN_P)                        TOKEN_P->_line_n    = self_line_number_at_begin();            TOKEN_P->_column_n  = self_column_number_at_begin();          TOKEN_P->end_line   = self_line_number_at_end();              TOKEN_P->end_column = self_column_number_at_end();

    

#   line 35 "quex_lexer-token.h"

 
typedef struct quex_Token_tag {
    QUEX_TYPE_TOKEN_ID    _id;

#   line 15 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"
    const QUEX_TYPE_CHARACTER* text;

#   line 44 "quex_lexer-token.h"

#   line 16 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"
    size_t                     len;

#   line 49 "quex_lexer-token.h"

#   line 17 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"
    size_t                     end_line;

#   line 54 "quex_lexer-token.h"

#   line 18 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"
    uint16_t                   end_column;

#   line 59 "quex_lexer-token.h"

#   line 20 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"
    uint32_t                   offset;

#   line 64 "quex_lexer-token.h"

#   line 19 "/home/pmderodat/build/libadalang/gpr/langkit/build/include/gpr_parser/gpr.qx"
    uint16_t                   last_id;

#   line 69 "quex_lexer-token.h"


#   ifdef     QUEX_OPTION_TOKEN_STAMPING_WITH_LINE_AND_COLUMN
#       ifdef QUEX_OPTION_LINE_NUMBER_COUNTING
        QUEX_TYPE_TOKEN_LINE_N    _line_n;
#       endif
#       ifdef  QUEX_OPTION_COLUMN_NUMBER_COUNTING
        QUEX_TYPE_TOKEN_COLUMN_N  _column_n;
#       endif
#   endif

} quex_Token;

QUEX_INLINE void quex_Token_construct(quex_Token*);
QUEX_INLINE void quex_Token_copy_construct(quex_Token*, 
                                             const quex_Token*);
QUEX_INLINE void quex_Token_copy(quex_Token*, const quex_Token*);
QUEX_INLINE void quex_Token_destruct(quex_Token*);

/* NOTE: Setters and getters as in the C++ version of the token class are not
 *       necessary, since the members are accessed directly.                   */

QUEX_INLINE void 
quex_Token_set(quex_Token*            __this, 
                 const QUEX_TYPE_TOKEN_ID ID);

extern const char*  quex_Token_map_id_to_name(const QUEX_TYPE_TOKEN_ID);

QUEX_INLINE bool 
quex_Token_take_text(quex_Token*              __this, 
                       QUEX_TYPE_ANALYZER*        analyzer, 
                       const QUEX_TYPE_CHARACTER* Begin, const QUEX_TYPE_CHARACTER* End);

#ifdef QUEX_OPTION_TOKEN_REPETITION_SUPPORT
QUEX_INLINE size_t quex_Token_repetition_n_get(quex_Token*);
QUEX_INLINE void   quex_Token_repetition_n_set(quex_Token*, size_t);
#endif /* QUEX_OPTION_TOKEN_REPETITION_SUPPORT */



#endif /* __QUEX_INCLUDE_GUARD__TOKEN__GENERATED__QUEX___TOKEN */
