------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                       Copyright (C) 2019, AdaCore                        --
--                                                                          --
-- This is  free  software;  you can redistribute it and/or modify it under --
-- terms of the  GNU  General Public License as published by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for more details.  You should have received  a copy of the  GNU  --
-- General Public License distributed with GNAT; see file  COPYING. If not, --
-- see <http://www.gnu.org/licenses/>.                                      --
--                                                                          --
------------------------------------------------------------------------------

package body GPR2.Source.Registry is

   ------------
   -- Shared --
   ------------

   protected body Shared is

      ---------
      -- Get --
      ---------

      function Get (Object : Source.Object) return Data is
      begin
         return Store (Object.Pathname);
      end Get;

      --------------
      -- Register --
      --------------

      procedure Register (Def : Data) is
      begin
         if Store.Contains (Def.Path_Name) then
            --  Increase the ref-counter
            declare
               D : Data := Store (Def.Path_Name);
            begin
               D.Ref_Count := D.Ref_Count + 1;
               Store (Def.Path_Name) := D;
            end;

         else
            Store.Insert (Def.Path_Name, Def);
         end if;
      end Register;

      ---------
      -- Set --
      ---------

      procedure Set (Object : Source.Object; Def : Data) is
      begin
         Store (Object.Pathname) := Def;
      end Set;

      --------------------
      -- Set_Other_Part --
      --------------------

      procedure Set_Other_Part (Object1, Object2 : Object) is
         P1   : constant Source_Store.Cursor := Store.Find (Object1.Pathname);
         P2   : constant Source_Store.Cursor := Store.Find (Object2.Pathname);
         Def1 : Data := Store (P1);
         Def2 : Data := Store (P2);
      begin
         Def1.Other_Part := Object2.Pathname;
         Def2.Other_Part := Object1.Pathname;

         Store.Replace_Element (P1, Def1);
         Store.Replace_Element (P2, Def2);
      end Set_Other_Part;

      ----------------
      -- Unregister --
      ----------------

      procedure Unregister (Object : in out Source.Object) is
         D : Data := Get (Object);
      begin
         D.Ref_Count := D.Ref_Count - 1;

         if D.Ref_Count = 0 then
            D.Units.Clear;
            Store.Delete (Object.Pathname);

            Object := Undefined;

         else
            Store (Object.Pathname) := D;
         end if;
      end Unregister;

   end Shared;

end GPR2.Source.Registry;
