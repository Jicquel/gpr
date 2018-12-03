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

with Ada.Characters.Handling;
with Ada.Directories;
with Ada.Strings.Unbounded;

with GNAT.Calendar.Time_IO;
with GNAT.OS_Lib;

with GPR2.Source.Registry;
with GPR2.Source.Parser;

package body GPR2.Source is

   use Ada.Strings.Unbounded;

   function Modification_Time (F : String) return Ada.Calendar.Time;

   function Key (Self : Object) return Value_Type
     with Inline, Pre => Self.Is_Defined;
   --  Returns the key for Self, this is used to compare a source object

   procedure Parse (Self : Object) with Inline;
   --  Run the parser on the given source and register information in the
   --  registry.

   ---------
   -- "<" --
   ---------

   function "<" (Left, Right : Object) return Boolean is
   begin
      return Key (Left) < Key (Right);
   end "<";

   ---------
   -- "=" --
   ---------

   overriding function "=" (Left, Right : Object) return Boolean is
   begin
      if not Left.Pathname.Is_Defined
        and then not Right.Pathname.Is_Defined
      then
         return True;
      else
         return Left.Pathname.Is_Defined = Right.Pathname.Is_Defined
           and then Key (Left) = Key (Right);
      end if;
   end "=";

   ------------
   -- Create --
   ------------

   function Create
     (Filename  : GPR2.Path_Name.Object;
      Kind      : Kind_Type;
      Language  : Name_Type;
      Unit_Name : Optional_Name_Type) return Object is
   begin
      return Result : Object do
         Registry.Shared.Register
           (Registry.Data'
              (Path_Name  => Filename,
               Timestamp  => Modification_Time (Filename.Value),
               Language   => To_Unbounded_String (String (Language)),
               Unit_Name  => To_Unbounded_String (String (Unit_Name)),
               Kind       => Kind,
               Other_Part => GPR2.Path_Name.Undefined,
               Units      => <>,
               Parsed     => False,
               Ref_Count  => 1));

         Result.Pathname := Filename;
      end return;
   end Create;

   --------------
   -- Has_Unit --
   --------------

   function Has_Unit (Self : Object) return Boolean is
   begin
      Parse (Self);
      return Registry.Shared.Get (Self).Unit_Name /= Null_Unbounded_String;
   end Has_Unit;

   ---------
   -- Key --
   ---------

   function Key (Self : Object) return Value_Type is
      use Ada.Characters;
      Data : constant Registry.Data := Registry.Shared.Get (Self);
   begin
      if Data.Unit_Name = Null_Unbounded_String then
         --  Not unit based
         return Data.Path_Name.Value;

      else
         return Kind_Type'Image (Data.Kind)
           & "|" & Handling.To_Lower (To_String (Data.Unit_Name));
      end if;
   end Key;

   ----------
   -- Kind --
   ----------

   function Kind (Self : Object) return Kind_Type is
   begin
      Parse (Self);
      return Registry.Shared.Get (Self).Kind;
   end Kind;

   --------------
   -- Language --
   --------------

   function Language (Self : Object) return Name_Type is
   begin
      return Name_Type (To_String (Registry.Shared.Get (Self).Language));
   end Language;

   -----------------------
   -- Modification_Time --
   -----------------------

   function Modification_Time (F : String) return Ada.Calendar.Time
   is
      use GNAT.OS_Lib;

      TS : String (1 .. 14);

      Y  : Year_Type;
      Mo : Month_Type;
      D  : Day_Type;
      H  : Hour_Type;
      Mn : Minute_Type;
      S  : Second_Type;

      Z : constant := Character'Pos ('0');

      T : OS_Time;

   begin
      T := File_Time_Stamp (F);

      pragma Assert (T /= Invalid_Time);

      GM_Split (T, Y, Mo, D, H, Mn, S);

      TS (01) := Character'Val (Z + Y / 1000);
      TS (02) := Character'Val (Z + (Y / 100) mod 10);
      TS (03) := Character'Val (Z + (Y / 10) mod 10);
      TS (04) := Character'Val (Z + Y mod 10);
      TS (05) := Character'Val (Z + Mo / 10);
      TS (06) := Character'Val (Z + Mo mod 10);
      TS (07) := Character'Val (Z + D / 10);
      TS (08) := Character'Val (Z + D mod 10);
      TS (09) := Character'Val (Z + H / 10);
      TS (10) := Character'Val (Z + H mod 10);
      TS (11) := Character'Val (Z + Mn / 10);
      TS (12) := Character'Val (Z + Mn mod 10);
      TS (13) := Character'Val (Z + S / 10);
      TS (14) := Character'Val (Z + S mod 10);

      return GNAT.Calendar.Time_IO.Value
        (TS (01 .. 08) & "T" & TS (09 .. 14));
   end Modification_Time;

   ----------------
   -- Other_Part --
   ----------------

   function Other_Part (Self : Object) return Object is
      Other_Part : constant GPR2.Path_Name.Object :=
                     Registry.Shared.Get (Self).Other_Part;
   begin
      if Other_Part = GPR2.Path_Name.Undefined then
         return Undefined;
      else
         return Object'(Pathname => Other_Part);
      end if;
   end Other_Part;

   -----------
   -- Parse --
   -----------

   procedure Parse (Self : Object) is
      use type Calendar.Time;

      S        : Registry.Data := Registry.Shared.Get (Self);
      Filename : constant String := Self.Pathname.Value;
   begin
      --  Parse if not yet parsed or if the file has changed on disk

      if not S.Parsed
        or else
          (Directories.Exists (Filename)
           and then S.Timestamp < Directories.Modification_Time (Filename))
      then
         declare
            Data : constant Source.Parser.Data :=
                     Source.Parser.Check (S.Path_Name);
         begin
            --  Check if separate unit

            if Data.Is_Separate then
               S.Kind := S_Separate;

            elsif S.Kind = S_Separate then
               --  It was a separate but not anymore, the source may have been
               --  changed to be a child unit.

               S.Kind := S_Body;
            end if;

            --  Record the withed units

            S.Units := Data.W_Units;

            --  The unit-name from the source if possible

            if Data.Unit_Name /= Null_Unbounded_String then
               S.Unit_Name := Data.Unit_Name;
            end if;

            --  Record that this is now parsed

            S.Parsed := True;

            --  Update registry

            Registry.Shared.Set (Self, S);
         end;
      end if;
   end Parse;

   ---------------
   -- Path_Name --
   ---------------

   function Path_Name (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Registry.Shared.Get (Self).Path_Name;
   end Path_Name;

   -------------
   -- Release --
   -------------

   procedure Release (Self : in out Object) is
   begin
      Registry.Shared.Unregister (Self);
   end Release;

   --------------------
   -- Set_Other_Part --
   --------------------

   procedure Set_Other_Part
     (Self       : Object;
      Other_Part : Object) is
   begin
      Registry.Shared.Set_Other_Part (Self, Other_Part);
   end Set_Other_Part;

   ----------------
   -- Time_Stamp --
   ----------------

   function Time_Stamp (Self : Object) return Calendar.Time is
   begin
      return Registry.Shared.Get (Self).Timestamp;
   end Time_Stamp;

   ---------------
   -- Unit_Name --
   ---------------

   function Unit_Name (Self : Object) return Name_Type is
   begin
      Parse (Self);
      return Name_Type (To_String (Registry.Shared.Get (Self).Unit_Name));
   end Unit_Name;

   ------------------
   -- Withed_Units --
   ------------------

   function Withed_Units (Self : Object) return Source_Reference.Set.Object is
   begin
      Parse (Self);
      return Registry.Shared.Get (Self).Units;
   end Withed_Units;

end GPR2.Source;
