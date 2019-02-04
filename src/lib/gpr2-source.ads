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

--  This package defines a source Object. This source object is shared with all
--  loaded project tree.

with Ada.Calendar;

with GPR2.Path_Name;
with GPR2.Source_Reference.Set;

package GPR2.Source is

   use Ada;
   use type GPR2.Path_Name.Object;

   type Object is tagged private;

   Undefined : constant Object;

   type Kind_Type is (S_Spec, S_Body, S_Separate);

   function Is_Defined (Self : Object) return Boolean;
   --  Returns true if Self is defined

   function "<" (Left, Right : Object) return Boolean;

   overriding function "=" (Left, Right : Object) return Boolean;
   --  A source object is equal if it is the same unit for unit based language,
   --  and if it is the same filename otherwise.

   function Path_Name (Self : Object) return Path_Name.Object
     with Pre => Self.Is_Defined;
   --  Returns the filename for the given source

   function Kind (Self : Object) return Kind_Type
     with Pre => Self.Is_Defined;
   --  Returns the kind of source

   function Other_Part (Self : Object) return Object
     with Pre => Self.Is_Defined;
   --  Returns the other-part of the source. This is either the spec for a body
   --  or the body for a spec.

   function Has_Unit (Self : Object) return Boolean
     with Pre => Self.Is_Defined;
   --  Returns True if source has unit information

   function Unit_Name (Self : Object) return Name_Type
     with Pre => Self.Is_Defined and then Self.Has_Unit;
   --  Returns the unit name for the given source or the empty string if the
   --  language does not have support for unit.

   function Language (Self : Object) return Name_Type
     with Pre => Self.Is_Defined;
   --  Returns the language for the given source

   function Withed_Units (Self : Object) return Source_Reference.Set.Object
     with Pre => Self.Is_Defined;
   --  Returns the list of withed units on this source

   function Time_Stamp (Self : Object) return Calendar.Time
     with Pre => Self.Is_Defined;
   --  Returns the time-stamp for this source

   function Create
     (Filename  : GPR2.Path_Name.Object;
      Kind      : Kind_Type;
      Language  : Name_Type;
      Unit_Name : Optional_Name_Type) return Object
     with Pre  => Filename.Is_Defined,
          Post => Create'Result.Is_Defined;
   --  Constructor for a source object

   procedure Set_Other_Part
     (Self       : Object;
      Other_Part : Object)
     with Pre => Self.Is_Defined and then Other_Part.Is_Defined;
   --  Sets the other-part for Self. The other-part is the body for a spec or
   --  the spec for a body or separate unit.

   procedure Release (Self : in out Object)
     with Pre => Self.Is_Defined;
   --  Releases source object if not referenced anymore

private

   type Object is tagged record
      Pathname : GPR2.Path_Name.Object := GPR2.Path_Name.Undefined;
   end record;

   Undefined : constant Object :=
                 Object'(Pathname => GPR2.Path_Name.Undefined);

   function Is_Defined (Self : Object) return Boolean is
     (Self /= Undefined);

end GPR2.Source;
