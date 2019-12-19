------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                     Copyright (C) 2019-2020, AdaCore                     --
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

--  Handle project's packages which are a set of attributes

with GPR2.Project.Attribute.Set;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Registry.Pack;
with GPR2.Project.Variable.Set;
with GPR2.Source_Reference.Identifier;

private with Ada.Strings.Unbounded;

package GPR2.Project.Pack is

   type Object is new Source_Reference.Object with private;

   Undefined : constant Object;
   --  This constant is equal to any object declared without an explicit
   --  initializer.

   subtype Project_Pack is Object;

   overriding function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function Create
     (Name       : Source_Reference.Identifier.Object;
      Attributes : Attribute.Set.Object;
      Variables  : Project.Variable.Set.Object) return Object;
   --  Creates a package object with the given Name and the list of attributes.
   --  Note that the list of attribute can be empty as a package can contain no
   --  declaration.

   function Name (Self : Object) return Name_Type
     with Pre => Self.Is_Defined;
   --  Returns the name of the project

   function Has_Attributes
     (Self  : Object;
      Name  : Optional_Name_Type := No_Name;
      Index : Value_Type := No_Value) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns true if the package has some attributes defined. If Name
   --  and/or Index are set it returns True if an attribute with the given
   --  Name and/or Index is defined.

   function Attributes
     (Self  : Object;
      Name  : Optional_Name_Type := No_Name;
      Index : Value_Type := No_Value) return Attribute.Set.Object
     with Pre => Self.Is_Defined;
   --  Returns all attributes defined for the package. Possibly an empty list
   --  if it does not contain attributes or if Name and Index does not match
   --  any attribute.

   function Check_Attribute
     (Self   : Object;
      Name   : Name_Type;
      Index  : Value_Type := No_Value;
      At_Num : Natural    := 0;
      Result : out Attribute.Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True and set Result to attribute if attribute exists or has
   --  default value, returns False and set Result to Undefined otherwise.

   function Attribute
     (Self  : Object;
      Name  : Name_Type;
      Index : Value_Type := No_Value) return Project.Attribute.Object
     with Pre =>
       Self.Is_Defined
       and then Self.Has_Attributes (Name, Index)
       and then Self.Attributes (Name, Index).Length = 1;
   --  Returns the Attribute with the given Name and possibly Index

   function Has_Variables
     (Self : Object;
      Name : Optional_Name_Type := No_Name) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns true if the package has some variables defined. If Name is set
   --  it returns True if a variable with the given Name is defined.

   function Variables (Self : Object) return Variable.Set.Object
     with Pre  => Self.Is_Defined,
          Post => (if Self.Has_Variables then not Variables'Result.Is_Empty);
   --  Returns all defined variables

   function Variable
     (Self : Object;
      Name : Name_Type) return Variable.Object
     with Pre  => Self.Is_Defined and then Self.Has_Variables (Name),
          Post => Variable'Result.Is_Defined;
   --  Returns variable named Name

   --  To ease the use of some attributes (some have synonyms for example)
   --  below are direct access to them.

   function Has_Spec_Suffix
     (Self     : Object;
      Language : Name_Type) return Boolean
     with Pre  => Self.Name = Name_Type (Registry.Pack.Naming);
   --  Returns True is package naming Self contains a Spec_Suffix attribute

   function Spec_Suffix
     (Self     : Object;
      Language : Name_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming)
               and then Self.Has_Spec_Suffix (Language),
       Post => Spec_Suffix'Result.Is_Defined;
   --  Handles Spec_Suffix and Specification_Suffix

   function Has_Body_Suffix
     (Self     : Object;
      Language : Name_Type) return Boolean
     with Pre  => Self.Name = Name_Type (Registry.Pack.Naming);
   --  Returns True is package naming Self contains a Body_Suffix attribute

   function Body_Suffix
     (Self     : Object;
      Language : Name_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming)
               and then Self.Has_Body_Suffix (Language),
       Post => Body_Suffix'Result.Is_Defined;
   --  Handles Body_Suffix and Implementation_Suffix

   function Has_Separate_Suffix
     (Self     : Object;
      Language : Name_Type) return Boolean
     with Pre  => Self.Name = Name_Type (Registry.Pack.Naming);
   --  Returns True is package naming Self contains a Separate_Suffix attribute

   function Separate_Suffix
     (Self     : Object;
      Language : Name_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming)
               and then Self.Has_Separate_Suffix (Language),
       Post => Separate_Suffix'Result.Is_Defined;
   --  Handles Separate_Suffix

   function Has_Specification
     (Self : Object;
      Unit : Value_Type) return Boolean
     with Pre  => Self.Name = Name_Type (Registry.Pack.Naming);
   --  Return True if package Naming Self has an attribute Specification or
   --  Spec defined for the given unit.

   function Specification
     (Self : Object;
      Unit : Value_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming)
               and then Self.Has_Specification (Unit),
       Post => Specification'Result.Is_Defined;
   --  Handles Spec, Specification, this is only defined for the Ada language

   function Has_Implementation
     (Self : Object;
      Unit : Value_Type) return Boolean
     with Pre  => Self.Name = Name_Type (Registry.Pack.Naming);
   --  Return True if package Naming Self has an attribute Implementation or
   --  Body defined for the given unit.

   function Implementation
     (Self : Object;
      Unit : Value_Type) return Project.Attribute.Object
     with
       Pre  => Self.Name = Name_Type (Registry.Pack.Naming)
               and then Self.Has_Implementation (Unit),
       Post => Implementation'Result.Is_Defined;
   --  Handles Body, Implementation, this is only defined for the Ada language

private

   use Ada.Strings.Unbounded;

   type Object is new Source_Reference.Object with record
      Name  : Unbounded_String;
      Attrs : Project.Attribute.Set.Object;
      Vars  : Project.Variable.Set.Object;
   end record;

   function Has_Separate_Suffix
     (Self     : Object;
      Language : Name_Type) return Boolean
   is
     (Self.Has_Attributes
        (Registry.Attribute.Separate_Suffix, Value_Type (Language)));

   function Has_Spec_Suffix
     (Self     : Object;
      Language : Name_Type) return Boolean
   is
     (Self.Has_Attributes
        (Registry.Attribute.Spec_Suffix, Value_Type (Language)));

   function Has_Body_Suffix
     (Self     : Object;
      Language : Name_Type) return Boolean
   is
     (Self.Has_Attributes
        (Registry.Attribute.Body_Suffix, Value_Type (Language)));

   function Has_Implementation
     (Self : Object;
      Unit : Value_Type) return Boolean
   is
     (Self.Has_Attributes (Registry.Attribute.Body_N, Unit));

   function Has_Specification
     (Self : Object;
      Unit : Value_Type) return Boolean
   is
     (Self.Has_Attributes (Registry.Attribute.Spec, Unit));

   Undefined : constant Object :=
                 (Source_Reference.Undefined with others => <>);

   overriding function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

end GPR2.Project.Pack;
