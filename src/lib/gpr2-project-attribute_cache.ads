------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                    Copyright (C) 2019-2021, AdaCore                      --
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

--  This is an internal GPR2 Unit used to implement a cache for attribute
--  evaluation. The cache protocol is the following:
--
--  C := Check_Cache (...);
--  if Has_Element (C) then
--     return Element (C);
--  end if;
--
--  Schedule_Update_Cache;
--
--  ... compute value to cache ...
--
--  Update_Cache (..., New_Value);
--
--  The cache is thread safe and lock-free on read operations. The lock-free
--  read is possible by using using some extra memory. It relies also in the
--  fact that in Indefinite_Hashed_Maps reallocation is done only if there is
--  need for new capacity.

with GPR2.Project.Attribute;
with GPR2.Project.Attribute_Index;

package GPR2.Project.Attribute_Cache is

   type Object is tagged private;

   type Cursor is private;

   function Check_Cache
      (Self   : Object;
       Name   : Attribute_Id;
       Pkg    : Optional_Package_Id            := No_Package;
       Index  : Project.Attribute_Index.Object := Attribute_Index.Undefined;
       At_Pos : Unit_Index                     := No_Index)
      return Cursor;

   function Has_Element (C : Cursor) return Boolean;

   function Element (C : Cursor) return GPR2.Project.Attribute.Object;

   procedure Schedule_Update_Cache (Self : Object);

   procedure Update_Cache
      (Self   : Object;
       Name   : Attribute_Id;
       Pkg    : Optional_Package_Id            := No_Package;
       Index  : Project.Attribute_Index.Object := Attribute_Index.Undefined;
       At_Pos : Unit_Index                     := No_Index;
       Attr   : GPR2.Project.Attribute.Object);

   procedure Clear_Cache (Self : Object);
   --  Empty the cache

   procedure Disable_Cache (Self : Object);
   --  Empty the cache, and do not store anything until the cache is re-enabled

   procedure Enable_Cache (Self : Object);
   --  Re-enable storage in the cache

private

   package Attribute_Cache_Maps is
        new Ada.Containers.Indefinite_Hashed_Maps
           (Key_Type        => String,
            Element_Type    => Project.Attribute.Object,
            Hash            => Ada.Strings.Hash,
            Equivalent_Keys => "=",
            "="             => Project.Attribute."=");

   type Map_Access is access Attribute_Cache_Maps.Map;

   type Count_Type_Access is access Ada.Containers.Count_Type;

   type Cursor is new Attribute_Cache_Maps.Cursor;

   type Inner_Object is record
      Enabled      : Boolean := True;
      Table        : Map_Access := null;
      Former_Table : Map_Access := null;
      Needed_Extra_Capacity : Ada.Containers.Count_Type := 0;
   end record;

   type Inner_Object_Access is access Inner_Object;

   type Object is new Ada.Finalization.Controlled with record
      Inner : Inner_Object_Access := null;
   end record;

   overriding procedure Initialize (Cache : in out Object);
   overriding procedure Finalize (Cache : in out Object);
   overriding procedure Adjust (Cache : in out Object);

   Min_Cache_Size : constant Ada.Containers.Count_Type := 128;
end GPR2.Project.Attribute_Cache;