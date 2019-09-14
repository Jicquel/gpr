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

--  This package defines the internal data structures used for representation
--  of Ada Library Information (ALI) acquired from the ALI files generated by
--  the front end.

with Ada.Containers.Indefinite_Ordered_Maps;

with GPR2.ALI.Dependency.List;
with GPR2.ALI.Unit.List;
with GPR2.Containers;
with GPR2.Path_Name;
with GPR2.Source;

package GPR2.ALI.Definition is

   use Ada;

   use GPR2.Containers;

   --
   --  Main object to hold ALI data
   --

   type Object is tagged private;

   Undefined : constant Object;

   function Scan_ALI (File : Path_Name.Object) return Object
     with Pre => File.Is_Defined;
   --  Scans an ALI file and returns the resulting object, or Undefined if
   --  something went wrong.

   function Is_Defined (Self : Object) return Boolean;

   function Dep_For
     (Self : Object; File : Simple_Name) return Dependency.Object
     with Pre => Self.Is_Defined;
   --  Returns the Dependency_Data object for File in Self

   function Units (Self : Object) return Unit.List.Object
     with Pre => Self.Is_Defined;
   --  Returns the list of Unit_Data objects in Self

   function Sdeps (Self : Object) return Dependency.List.Object
     with Pre => Self.Is_Defined;
   --  Returns the list of Dependency_Data objects in Self

   procedure Print_ALI (Self : Object)
     with Pre => Self.Is_Defined;
   --  Debug util

private

   package Sdep_Map_Package is new
     Ada.Containers.Indefinite_Ordered_Maps (Simple_Name, Positive);

   subtype Sdep_Map is Sdep_Map_Package.Map;

   Empty_Sdep_Map : constant Sdep_Map := Sdep_Map_Package.Empty_Map;

   type Object is tagged record

      Ofile_Full_Name : Unbounded_String;
      --  Full name of object file corresponding to the ALI file

      Args : Value_List;
      --  Args for this file

      Units : Unit.List.Object;
      --  Units for this file

      Sdeps : Dependency.List.Object;
      --  Source deps for this file

      Sdeps_Map : Sdep_Map;
      --  Map to File names (as Simple_Name) to index in Sdeps

      GNAT_Version : Unbounded_String;
      --  GNAT version used to generate this file (first line in ALI)

      Compile_Errors : Boolean := False;
      --  Set to True if compile errors for unit. Note that No_Object will
      --  always be set as well in this case. Not set if 'P' appears in
      --  Ignore_Lines.

      No_Object : Boolean := False;
      --  Set to True if no object file generated. Not set if 'P' appears in
      --  Ignore_Lines.

   end record;

   Undefined : constant Object :=
                 (Ofile_Full_Name => Null_Unbounded_String,
                  Args            => Value_Type_List.Empty_Vector,
                  Units           => Unit.List.Empty_List,
                  Sdeps           => Dependency.List.Empty_List,
                  Sdeps_Map       => Empty_Sdep_Map,
                  GNAT_Version    => Null_Unbounded_String,
                  Compile_Errors  => False,
                  No_Object       => False);

   function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

   function Sdeps (Self : Object) return Dependency.List.Object is
     (Self.Sdeps);

   function Units (Self : Object) return Unit.List.Object is
     (Self.Units);

end GPR2.ALI.Definition;