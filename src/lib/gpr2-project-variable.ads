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

with GPR2.Project.Name_Values;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Typ;
with GPR2.Source_Reference.Identifier;
with GPR2.Source_Reference.Value;

package GPR2.Project.Variable is

   use type Project.Registry.Attribute.Value_Kind;

   type Object is new Name_Values.Object with private;

   subtype Project_Variable is Object;

   Undefined : constant Object;

   package PRA renames Project.Registry.Attribute;

   function Create
     (Name  : Source_Reference.Identifier.Object;
      Value : Source_Reference.Value.Object;
      Typ   : Project.Typ.Object) return Object
     with Post => Create'Result.Kind = PRA.Single
                  and then Create'Result.Name.Text = Name.Text
                  and then Create'Result.Count_Values = 1;
   --  Create a single-valued object

   function Create
     (Name   : Source_Reference.Identifier.Object;
      Values : Containers.Source_Value_List;
      Typ    : Project.Typ.Object) return Object
     with Post => Create'Result.Kind = PRA.List
                  and then Create'Result.Name.Text = Name.Text
                  and then Create'Result.Count_Values = Values.Length;
   --  Create a multi-valued object

   overriding function Create
     (Name  : Source_Reference.Identifier.Object;
      Value : Source_Reference.Value.Object) return Object
     with Post => Create'Result.Kind = PRA.Single
                  and then Create'Result.Name.Text = Name.Text
                  and then Create'Result.Count_Values = 1;
   --  Create a single-valued object

   overriding function Create
     (Name   : Source_Reference.Identifier.Object;
      Values : Containers.Source_Value_List) return Object
     with Post => Create'Result.Kind = PRA.List
                  and then Create'Result.Name.Text = Name.Text
                  and then Create'Result.Count_Values = Values.Length;

   overriding function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function Has_Type (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if the variable has a type information

   function Typ (Self : Object) return Typ.Object
     with Pre => Self.Is_Defined and then Self.Has_Type;
   --  Returns the type for the variable Self

   overriding function Rename
     (Self : Object;
      Name : Source_Reference.Identifier.Object) return Object
     with Pre => Self.Is_Defined;
   --  Returns the object with another name

   overriding function Image
     (Self : Object; Name_Len : Natural := 0) return String
     with Pre => Self.Is_Defined;
   --  Returns a string representation

private

   type Object is new Name_Values.Object with record
      Typ : Project.Typ.Object;
   end record;

   function Has_Type (Self : Object) return Boolean is
     (Self.Typ.Is_Defined);

   function Typ (Self : Object) return Project.Typ.Object is  (Self.Typ);

   Undefined : constant Object := (Name_Values.Undefined with Typ => <>);

   overriding function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

end GPR2.Project.Variable;
