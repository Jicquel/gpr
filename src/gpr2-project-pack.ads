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

--  Handle project's packages which are a set of attributes

with GPR2.Containers;
with GPR2.Project.Attribute.Set;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Registry.Pack;
with GPR2.Source_Reference;

package GPR2.Project.Pack is

   use type Containers.Count_Type;
   use type Project.Attribute.Object;

   type Object is new Source_Reference.Object with private;

   Undefined : constant Object;

   subtype Project_Pack is Object;

   function Create
     (Name       : Name_Type;
      Attributes : Attribute.Set.Object;
      Sloc       : Source_Reference.Object) return Object;
   --  Create a package object with the given Name and the list of attributes.
   --  Note that the list of attribute can be empty as a package can contain no
   --  declaration.

   function Name (Self : Object) return Name_Type
     with Pre => Self /= Undefined;
   --  Returns the name of the project

   function Has_Attributes
     (Self  : Object;
      Name  : Optional_Name_Type := "";
      Index : Value_Type := "") return Boolean
     with Pre => Self /= Undefined;
   --  Returns true if the package has some attributes defined. If Name
   --  and/or Index are set it returns True if an attribute with the given
   --  Name and/or Index is defined.

   function Attributes
     (Self  : Object;
      Name  : Optional_Name_Type := "";
      Index : Value_Type := "") return Attribute.Set.Object
     with Pre => Self /= Undefined;
   --  Returns all attributes defined for the package. Possibly an empty list
   --  if it does not contain attributes or if Name and Index does not match
   --  any attribute.

   function Attribute
     (Self  : Object;
      Name  : Name_Type;
      Index : Value_Type := "") return Project.Attribute.Object
     with Pre =>
       Self /= Undefined
       and then Self.Has_Attributes (Name, Index)
       and then Self.Attributes (Name, Index).Length = 1;
   --  Returns the Attribute with the given Name and possibly Index

   --  To ease the use of some attributes (some have synonyms for example)
   --  below are direct access to them.

   function Spec_Suffix
     (Self     : Object;
      Language : Name_Type) return Project.Attribute.Object
     with Pre => Self.Name = Name_Type (Registry.Pack.Naming);

   function Body_Suffix
     (Self     : Object;
      Language : Name_Type) return Project.Attribute.Object
     with Pre => Self.Name = Name_Type (Registry.Pack.Naming);

   function Separate_Suffix
     (Self     : Object;
      Language : Name_Type) return Project.Attribute.Object
     with Pre => Self.Name = Name_Type (Registry.Pack.Naming);

   function Specification
     (Self : Object;
      Unit : Value_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming),
       Post =>
         (if Specification'Result = Project.Attribute.Undefined
          then
            not Self.Has_Attributes (Registry.Attribute.Spec)
              and then
            not Self.Has_Attributes (Registry.Attribute.Specification));
   --  Handles Spec, Specification, this is only defined for the Ada language

   function Implementation
     (Self : Object;
      Unit : Value_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming),
       Post =>
         (if Implementation'Result = Project.Attribute.Undefined
          then
            not Self.Has_Attributes (Registry.Attribute.Body_N)
              and then
            not Self.Has_Attributes (Registry.Attribute.Implementation));
   --  Handles Body, Implementation, this is only defined for the Ada language

private

   type Object is new Source_Reference.Object with record
      Name  : Unbounded_String;
      Attrs : Project.Attribute.Set.Object;
   end record;

   Undefined : constant Object :=
                 Object'(Source_Reference.Object
                         with Null_Unbounded_String, Attrs => <>);

end GPR2.Project.Pack;
