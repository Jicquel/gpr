--
--  Copyright (C) 2020-2023, AdaCore
--
--  SPDX-License-Identifier: Apache-2.0
--

package body Counters is

   procedure Bump (C : in out Counter) is
   begin
      C.Value := C.Value + 1;
   end Bump;

   procedure Reset (C : in out Counter) is
   begin
      C.Value := 0;
   end Reset;

end Counters;
