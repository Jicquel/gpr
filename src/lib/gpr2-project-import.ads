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

with GPR2.Source_Reference;

package GPR2.Project.Import is

   use type GPR2.Source_Reference.Object;

   type Object is new Source_Reference.Object with private;

   subtype Import_Type is Object;

   Undefined : constant Object;

   overriding function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function Create
     (Path_Name  : GPR2.Path_Name.Object;
      Sloc       : Source_Reference.Object;
      Is_Limited : Boolean) return Object
     with Pre => Sloc.Is_Defined;

   function Path_Name (Self : Object) return Path_Name.Object
     with Pre => Self.Is_Defined;
   --  Full pathname of the corresponding project file

   function Is_Limited (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if this is a limited import

private

   type Object is new Source_Reference.Object with record
      Path_Name  : GPR2.Path_Name.Object;
      Is_Limited : Boolean := False;
   end record;

   Undefined : constant Object :=
                 (Source_Reference.Undefined with others => <>);

   overriding function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

end GPR2.Project.Import;
