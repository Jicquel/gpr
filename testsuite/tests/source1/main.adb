------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--            Copyright (C) 2016, Free Software Foundation, Inc.            --
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
------------------------------------------------------------------------------

with Ada.Strings.Fixed;
with Ada.Text_IO;

with GPR2.Project.View;
with GPR2.Project.Tree;
with GPR2.Source;

procedure Main is

   use Ada;
   use GPR2;
   use GPR2.Project;

   procedure Check (Project_Name : String);
   --  Do check the given project's sources

   procedure Output_Filename (Filename : Name_Type);
   --  Remove the leading tmp directory

   -----------
   -- Check --
   -----------

   procedure Check (Project_Name : String) is
      Prj  : Project.Tree.Object;
      View : Project.View.Object;
   begin
      Prj := Project.Tree.Load (Create (Project_Name));

      View := Prj.Root_Project;
      Text_IO.Put_Line ("Project: " & View.Name);

      for Source of View.Sources loop
         declare
            S : constant GPR2.Source.Object := Source.Source;
            U : constant Value_Type := S.Unit_Name;
         begin
            Output_Filename (S.Filename);

            Text_IO.Set_Col (16);
            Text_IO.Put ("   language: " & S.Language);

            Text_IO.Set_Col (33);
            Text_IO.Put ("   Kind: " & GPR2.Source.Kind_Type'Image (S.Kind));

            if U /= "" then
               Text_IO.Put ("   unit: " & U);
            end if;

            Text_IO.New_Line;
         end;
      end loop;
   end Check;

   ---------------------
   -- Output_Filename --
   ---------------------

   procedure Output_Filename (Filename : Name_Type) is
      I : constant Positive := Strings.Fixed.Index (Filename, "source1/");
   begin
      Text_IO.Put (" > " & Filename (I + 8 .. Filename'Last));
   end Output_Filename;

begin
   Check ("demo1.gpr");
   Check ("demo2.gpr");
end Main;
