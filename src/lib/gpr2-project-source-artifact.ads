------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--            Copyright (C) 2018, Free Software Foundation, Inc.            --
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

--  The artifacts that are generated by the compilation of a source file of a
--  given project.

with GPR2.Path_Name;
with GPR2.Project.Source;
with GPR2.Project.View;

package GPR2.Project.Source.Artifact is

   type Object is tagged private;

   Undefined : constant Object;

   function Create
     (Source      : GPR2.Project.Source.Object;
      Object      : Path_Name.Object;
      Dependency  : Path_Name.Object := Path_Name.Undefined)
      return Artifact.Object
     with Pre => Source /= GPR2.Project.Source.Undefined;
   --  Constructor for Object defining the artifacts for the given Source

   function Source (Self : Object) return GPR2.Project.Source.Object
     with Pre => Self /= Undefined;
   --  The project's source used to generate the artifacts

   function Has_Object_Code (Self : Object) return Boolean
     with Pre => Self /= Undefined;

   function Object_Code (Self : Object) return Path_Name.Object
     with Pre => Self /= Undefined;
   --  The target-dependent code (generally .o or .obj)

   function Has_Dependency (Self : Object) return Boolean
     with Pre => Self /= Undefined;

   function Dependency (Self : Object) return Path_Name.Object
     with Pre => Self /= Undefined;
   --  A file containing information (.ali for GNAT, .d for GCC) like
   --  cross-reference, units used by the source, etc.

private

   type Object is tagged record
      Source     : Project.Source.Object;
      Object     : Path_Name.Object := Path_Name.Undefined;
      Dependency : Path_Name.Object := Path_Name.Undefined;
   end record;

   Undefined : constant Object :=
                 (Source     => <>,
                  Object     => Path_Name.Undefined,
                  Dependency => Path_Name.Undefined);

   function Has_Object_Code (Self : Object) return Boolean is
     (Self.Object /= Path_Name.Undefined);

   function Has_Dependency (Self : Object) return Boolean is
     (Self.Dependency /= Path_Name.Undefined);

end GPR2.Project.Source.Artifact;