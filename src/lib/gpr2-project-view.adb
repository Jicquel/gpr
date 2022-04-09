------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--                    Copyright (C) 2019-2022, AdaCore                      --
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

with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with System.Assertions;

with GNAT.OS_Lib;
with GNATCOLL.Utils;
with GNAT.Regexp; use GNAT.Regexp;

with GPR2.Message;
with GPR2.Project.Attribute_Cache;
with GPR2.Project.Definition;
with GPR2.Project.Source.Set;
with GPR2.Project.Tree;
with GPR2.Project.View.Set;
with GPR2.Source_Info;
with GPR2.Project.Unit_Info;
with GPR2.Source_Reference.Attribute;
with GPR2.Source_Reference.Pack;

package body GPR2.Project.View is

   use GNAT;

   function Get_Ref (View : Object) return Definition.Ref is
     (Definition.Data (View.Get.Element.all)'Unchecked_Access);

   function Get_RO (View : Object) return Definition.Const_Ref is
     (Definition.Data (View.Get.Element.all)'Unchecked_Access);

   function Get_RW (View : in out Object) return Definition.Ref is
     (Definition.Data (View.Get.Element.all)'Unchecked_Access);

   function Refcount (Self : Object) return Natural is
     (Definition_References.Get_Refcount (Self));
   --  Get view refcount

   procedure Set_Def (Ref : out View.Object; Def : Definition_Base'Class);
   --  Convert definition to view

   function Apply_Root_And_Subdirs
     (Self : Object; Dir_Attr : Attribute_Id) return GPR2.Path_Name.Object
     with Pre => Dir_Attr in PRA.Object_Dir | PRA.Library_Ali_Dir |
                             PRA.Library_Dir | PRA.Exec_Dir |
                             PRA.Library_Src_Dir;
   --  Apply project path and subdir option for library, object and executable
   --  directories defined in attribute Dir_Attr.

   function Weak (View : Object) return Weak_Reference is
     (Definition_References.Weak (View));

   function Strong (Weak : Weak_Reference) return Object;

   function Binder_Prefix
     (Self : Object; Language : Language_Id) return Filename_Optional
     with Pre => Self.Is_Defined;
   --  Prefix to be used for the binder exchange file name for the language.
   --  Used to have different binder exchange file names when binding different
   --  languages.

   function Remove_Body_Suffix
     (Self : Object; Name : Simple_Name) return Value_Not_Empty;
   --  Remove body suffix from Name

   function Attributes_Internal
     (Self          : Object;
      Pack          : Optional_Package_Id;
      Name          : Attribute_Id;
      With_Defaults : Boolean := True;
      With_Config   : Boolean := True)
      return Project.Attribute.Set.Object
   with Inline;

   -------------------------
   -- Aggregate_Libraries --
   -------------------------

   function Aggregate_Libraries (Self : Object) return Set.Object is
      Result : Set.Object;
   begin
      for Id of Definition.Get_RO (Self).Agg_Libraries loop
         Result.Include (Self.Tree.Instance_Of (Id));
      end loop;

      return Result;
   end Aggregate_Libraries;

   ----------------
   -- Aggregated --
   ----------------

   function Aggregated (Self : Object) return Set.Object is
   begin
      return Set : GPR2.Project.View.Set.Object do
         for Agg of Definition.Get_RO (Self).Aggregated loop
            Set.Insert (Agg);
         end loop;
      end return;
   end Aggregated;

   ----------------------------
   -- Apply_Root_And_Subdirs --
   ----------------------------

   function Apply_Root_And_Subdirs
     (Self : Object; Dir_Attr : Attribute_Id) return GPR2.Path_Name.Object
   is
      function Compute return GPR2.Path_Name.Object;

      -------------
      -- Compute --
      -------------

      function Compute return GPR2.Path_Name.Object is
         Dir      : constant Value_Type :=
                      Self.Attribute (Dir_Attr).Value.Text;
         Subdirs  : constant Filename_Optional := Self.Tree.Subdirs;
         Dir_Name : constant Filename_Type :=
                      (if Dir = "" then "." else Filename_Type (Dir));
         Result   : GPR2.Path_Name.Object;
      begin
         if OS_Lib.Is_Absolute_Path (Dir) then
            Result := GPR2.Path_Name.Create_Directory (Dir_Name);

         elsif Self.Tree.Build_Path.Is_Defined then
            Result := GPR2.Path_Name.Create_Directory
              (Self.Dir_Name.Relative_Path
                 (Self.Tree.Root_Project.Dir_Name).Name,
               Filename_Type (Self.Tree.Build_Path.Value));

            Result := GPR2.Path_Name.Create_Directory
              (Dir_Name, Filename_Type (Result.Value));

         else
            Result := GPR2.Path_Name.Create_Directory
              (Dir_Name, Filename_Type (Self.Dir_Name.Value));
         end if;

         if Subdirs = No_Filename then
            return Result;
         end if;

         return GPR2.Path_Name.Create_Directory
           (Subdirs, Filename_Type (Result.Value));
      end Compute;

      Def      : Definition.Ref renames Self.Get_Ref;
      Def_Attr : Definition.Cacheable_Dir_Attrs;

   begin
      if Dir_Attr = PRA.Object_Dir then
         Def_Attr := Definition.Object_Dir;
      elsif Dir_Attr = PRA.Library_Ali_Dir then
         Def_Attr := Definition.Library_Ali_Dir;
      elsif Dir_Attr = PRA.Library_Dir then
         Def_Attr := Definition.Library_Dir;
      elsif Dir_Attr = PRA.Exec_Dir then
         Def_Attr := Definition.Exec_Dir;
      elsif Dir_Attr = PRA.Library_Src_Dir then
         Def_Attr := Definition.Library_Src_Dir;
      end if;

      if not Def.Dir_Cache (Def_Attr).Is_Set then
         Def.Dir_Cache (Def_Attr) :=
           (Is_Set => True,
            Value  => Compute);
      end if;

      return Def.Dir_Cache (Def_Attr).Value;
   end Apply_Root_And_Subdirs;

   ---------------
   -- Artifacts --
   ---------------

   function Artifacts (Self : Object) return GPR2.Path_Name.Set.Object is
      Result : GPR2.Path_Name.Set.Object;

      procedure Result_Append
        (Dir : GPR2.Path_Name.Object; Attr : Attribute_Id);
      --  Append files created from directory name and filenames from list of
      --  attributes.

      -------------------
      -- Result_Append --
      -------------------

      procedure Result_Append
        (Dir : GPR2.Path_Name.Object; Attr : Attribute_Id)
      is
         use Ada.Directories;
         Item : Directory_Entry_Type;
         Find : Search_Type;
      begin
         if not Exists (Dir.Value) then
            return;
         end if;

         for Name of Self.Clean_Attribute_List (Attr, No_Language) loop
            Start_Search
              (Search    => Find,
               Directory => Dir.Value,
               Pattern   => Name,
               Filter    => (Ordinary_File => True, others => False));

            while More_Entries (Find) loop
               Get_Next_Entry (Find, Item);

               Result.Append
                 (GPR2.Path_Name.Create_File
                    (Filename_Type (Full_Name (Item))));
            end loop;
         end loop;
      end Result_Append;

   begin
      Result_Append (Self.Object_Directory, PRA.Artifacts_In_Object_Dir);

      if Self.Kind = K_Standard then
         Result_Append (Self.Executable_Directory, PRA.Artifacts_In_Exec_Dir);
      end if;

      return Result;
   end Artifacts;

   ---------------
   -- Attribute --
   ---------------

   function Attribute
     (Self   : Object;
      Name   : Attribute_Id;
      Pack   : Optional_Package_Id    := No_Package;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Unit_Index             := No_Index)
      return Project.Attribute.Object
   is
      use type Project.Attribute_Index.Object;
      use type PRA.Index_Value_Type;
      use type PRA.Inherit_From_Extended_Type;

      --  Compute the attribute qualified name

      PRA_Name  : constant PRA.Qualified_Name := PRA.Create (Name, Pack);
      Alias     : constant Optional_Attribute_Id := PRA.Alias (PRA_Name).Attr;
      Has_Index : constant Boolean := Index /= Attribute_Index.Undefined;
      PRA_Def   : PRA.Def;
      Result    : Project.Attribute.Object;

      function Found (Attribute : Project.Attribute.Object) return Boolean
         with Inline => True;

      function Get_Attribute_From_View
        (View : Object) return Project.Attribute.Object;
      --  Internal function to get attribute from a view

      procedure Check_Matching_Index
        (Pattern : Project.Attribute.Object;
         Result  : in out Project.Attribute.Object);

      procedure Get_Config_Attribute;
      --  Returns the config attribute value for Name if given on the command
      --  line.

      function Get_Default_Index return Value_Type;

      --------------------------
      -- Check_Matching_Index --
      --------------------------

      procedure Check_Matching_Index
        (Pattern : Project.Attribute.Object;
         Result  : in out Project.Attribute.Object)
      is
         use type Source_Reference.Object;
      begin
         if Match (Index.Text,
                   Compile
                     (Pattern.Index.Text,
                      Glob           => True,
                      Case_Sensitive => Pattern.Index.Is_Case_Sensitive))
         then
            if not Found (Result)
              or else
                Source_Reference.Object (Result)
                  < Source_Reference.Object (Pattern)
            then
               Result := Pattern;
            end if;
         end if;
      end Check_Matching_Index;

      -----------
      -- Found --
      -----------

      function Found (Attribute : Project.Attribute.Object) return Boolean is
      begin
         --  Found if attribute is defined and not a default value, or is
         --  read_only (builtin value).

         return Attribute.Is_Defined and then
           (not Attribute.Is_Default or else PRA_Def.Builtin);
      end Found;

      -----------------------------
      -- Get_Attribute_From_View --
      -----------------------------

      function Get_Attribute_From_View
        (View : Object) return Project.Attribute.Object
      is
         function Get_Pack return Project.Pack.Set.Cursor with Inline;
         function Get_Attrs return Project.Attribute.Set.Object with Inline;

         ---------------
         -- Get_Attrs --
         ---------------

         function Get_Attrs return Project.Attribute.Set.Object is
         begin
            if Pack = No_Package then
               return View.Get_RO.Attrs;
            end if;

            declare
               Cursor : Project.Pack.Set.Cursor renames Get_Pack;
            begin
               if Project.Pack.Set.Has_Element (Cursor) then
                  return Project.Pack.Set.Element (Cursor).Attrs;
               else
                  return Project.Attribute.Set.Empty_Set;
               end if;
            end;
         end Get_Attrs;

         --------------
         -- Get_Pack --
         --------------

         function Get_Pack return Project.Pack.Set.Cursor is
            Def    : Definition.Const_Ref := View.Get_RO;
            Result : Project.Pack.Set.Cursor;
         begin
            loop
               Result := Def.Packs.Find (Pack);
               if Project.Pack.Set.Has_Element (Result) then
                  return Result;
               end if;

               exit when not Def.Extended_Root.Is_Defined;

               Def := Def.Extended_Root.Get_RO;
            end loop;

            return Result;
         end Get_Pack;

         Result : Project.Attribute.Object;
         Attrs  : Project.Attribute.Set.Object renames Get_Attrs;

      begin
         --  First try to find an exact match

         Result := Attrs.Element (Name, Index, At_Pos);

         if not Found (Result) and then Alias /= No_Attribute then
            Result := Attrs.Element (Alias, Index, At_Pos);
         end if;

         --  Checks for special index matching

         if not Found (Result)
           and then Index.Is_Defined
           and then Index.Value'Length > 0
         then
            if PRA_Def.Index_Type = PRA.FileGlob_Index
              or else
                (PRA_Def.Index_Type = PRA.FileGlob_Or_Language_Index
                 and then not Self.Has_Language (Name_Type (Index.Value)))
            then
               --  The index might match a globbing pattern. In that case
               --  iterate over the attributes to find one that match the
               --  index.

               for Attr of Attrs loop
                  if Attr.Name.Id = Name
                    or else (Alias /= No_Attribute
                             and then Attr.Name.Id = Alias)
                  then
                     --  We should have a file name. Let's do pattern
                     --  matching.

                     Check_Matching_Index
                       (Pattern => Attr,
                        Result  => Result);

                     --  Note: we need to keep going here as last
                     --  match will be the one to take into account.
                  end if;
               end loop;
            end if;

            --  Now if we have a source as index, and haven't found any result
            --  and the attribute is defined for the source's language, let's
            --  return it.
            --  Depending on when this is called, be careful that the view may
            --  not be fully loaded yet (so of course no source available, but
            --  worse: check for source will blow because Root_View is not
            --  set at parse time but a bit later).

            if not Found (Result)
              and then PRA_Def.Index_Type = PRA.FileGlob_Or_Language_Index
              and then not Get_RO (Self).Root_View.Was_Freed
              and then Self.Has_Source (GPR2.Simple_Name (Index.Value))
            then
               declare
                  Src : Project.Source.Object renames
                          Self.Source (GPR2.Simple_Name (Index.Value));
               begin
                  Result :=
                    Attribute (View, Name, Pack, PAI.Create (Src.Language));
               end;
            end if;

            --  Finally, check if an attribute with the "others" index is
            --  defined.

            if not Found (Result)
              and then PRA_Def.Index_Optional
            then
               Result :=
                 Attrs.Element (Name, Project.Attribute_Index.I_Others);

               if not Found (Result) and then Alias /= No_Attribute then
                  Result :=
                    Attrs.Element (Alias, Project.Attribute_Index.I_Others);
               end if;
            end if;
         end if;

         if Pack = No_Package
           and then PRA_Def.Inherit_From_Extended /= PRA.Not_Inherited
           and then View.Is_Extending
         then
            if not Found (Result) then
               return Get_Attribute_From_View (View.Extended_Root);

            elsif PRA_Def.Inherit_From_Extended = PRA.Concatenated then
               --  We need to fetch to concatenate the attribute value with
               --  the value from the extended project.

               declare
                  Result2 : Project.Attribute.Object;
               begin
                  Result2 := Get_Attribute_From_View (View.Extended_Root);

                  if Found (Result2) then
                     Result.Prepend_Vector (Result2);
                  end if;
               end;
            end if;
         end if;

         return Result;
      end Get_Attribute_From_View;

      --------------------------
      -- Get_Config_Attribute --
      --------------------------

      procedure Get_Config_Attribute is

         package SR renames Source_Reference;
         package SRA renames Source_Reference.Attribute;
         package SRV renames Source_Reference.Value;

         function From_Command_Line return Value_Type;

         -----------------------
         -- From_Command_Line --
         -----------------------

         function From_Command_Line return Value_Type is
         begin
            if Name = PRA.Target
              or else Name = PRA.Canonical_Target
            then
               if Self.Tree.Target_From_Command_Line /= "all"
                 and then Self.Tree.Target_From_Command_Line /= ""
               then
                  return Value_Type
                    (Self.Tree.Target_From_Command_Line
                       (Normalized => Name = PRA.Canonical_Target));
               end if;

            elsif Name = PRA.Runtime
              and then Index.Is_Defined
            then
               declare
                  Lang : constant Language_Id :=
                           +Optional_Name_Type (Index.Value);
               begin
                  return
                    Value_Type (Self.Tree.Runtime_From_Command_Line (Lang));
               end;
            end if;

            return "";
         end From_Command_Line;

         Cmd_Line : constant Value_Type := From_Command_Line;

      begin
         if Cmd_Line'Length > 0 then
            --  Value from command line always have priority over all other
            --  considerations.

            Result := PA.Create
              (Name  => SRA.Object (SRA.Create (SR.Builtin, Name)),
               Index => Index,
               Value => SRV.Object (SRV.Create (SR.Builtin, Cmd_Line)));

            return;
         end if;

         --  Return the value from the configuration project when it exists.
         --  It takes priority over any explicitly defined value for the
         --  view: the user may override such value from the command line
         --  (--RTS) or via an explicit config project.

         if Self.Tree.Has_Configuration
           and then Self.Tree.Configuration.Corresponding_View /= Self
         then
            Result := Get_Attribute_From_View
                        (Self.Tree.Configuration.Corresponding_View);

            if Result.Is_Defined and then not Result.Is_Default then
               --  Set the From_Config flag for the attribute
               Result.Set_From_Config (True);
            end if;

            if not Result.Is_Defined
              and then Name = PRA.Runtime
              and then Index.Is_Defined
            then
               --  Runtime names are not defined in the configuration project.
               --  However, we have them in our config parameters when run in
               --  autoconfig mode. Let's use that.

               declare
                  Value : constant Value_Type :=
                            Value_Type
                              (Self.Tree.Configuration.Runtime
                                 (+Optional_Name_Type (Index.Value)));
               begin
                  if Value'Length > 0 then
                     Result := PA.Create
                       (Name  => SRA.Object (SRA.Create (SR.Builtin, Name)),
                        Index => Index,
                        Value => SRV.Object (SRV.Create (SR.Builtin, Value)));
                     Result.Set_From_Config (True);
                  end if;
               end;
            end if;
         end if;

         --  At this point, if Result is undefined, we are in autoconf mode
         --  and don't have config yet. Let's use the regular attribute
         --  resolution.
      end Get_Config_Attribute;

      -----------------------
      -- Get_Default_Index --
      -----------------------

      function Get_Default_Index return Value_Type is
      begin
         if not Has_Index then
            return Registry.Attribute.Any_Index;
         else
            return Index.Value (Preserve_Case => Index.Is_Case_Sensitive);
         end if;
      end Get_Default_Index;

      Cache_Cursor : constant Project.Attribute_Cache.Cursor :=
         Definition.Get_RO (Self).Cache.Check_Cache
            (Name   => Name,
             Pkg    => Pack,
             Index  => Index,
             At_Pos => At_Pos);
   begin
      if Project.Attribute_Cache.Has_Element (Cache_Cursor) then
         return Project.Attribute_Cache.Element (Cache_Cursor);
      end if;

      Definition.Get_RO (Self).Cache.Schedule_Update_Cache;

      --  First check if the attribute is defined in the registry

      if not PRA.Exists (PRA_Name) then
         raise Attribute_Error
            with PRA.Image (PRA_Name) & " attribute does not exist";
      end if;

      --  Fetch the attribute definition

      PRA_Def := PRA.Get (PRA_Name);

      --  Check if index is used correctly

      if PRA_Def.Index_Type = PRA.No_Index and then Has_Index then
         raise Attribute_Error
            with PRA.Image (PRA_Name) & " attribute does not accept index";
      end if;

      --  Attributes that denote toolchain configuration need special
      --  handling: in particular they may be overwritten by the command
      --  line, via --target or --RTS switches.

      if PRA_Def.Is_Toolchain_Config then
         Get_Config_Attribute;
      end if;

      --  Try to fetch the attribute from the view

      if not Result.Is_Defined then
         Result := Get_Attribute_From_View (View => Self);
      end if;

      --  Handle configuration project

      if GPR2.Project.Tree.Has_Configuration (Self.Tree.all)
        and then Self.Tree.Configuration.Corresponding_View /= Self
      then
         if not Found (Result) then
            --  If at this stage Result is not defined try to fetch the value
            --  from the configuration project.

            Result := Get_Attribute_From_View
              (View => Self.Tree.Configuration.Corresponding_View);

            if Result.Is_Defined then
               --  Set the From_Config flag for the attribute
               Result.Set_From_Config (True);
            end if;

         elsif PRA_Def.Config_Concatenable then
            --  If the attribute value has been found, prepend if necessary
            --  the value from the configuration project.

            declare
               Result2 : Project.Attribute.Object;
            begin
               Result2 := Get_Attribute_From_View
                 (View => Self.Tree.all.Configuration.Corresponding_View);

               if Found (Result2) then
                  Result.Prepend_Vector (Result2);
               end if;
            end;
         end if;
      end if;

      --  The "Found" subprogram rejects default values: so here we just check
      --  if result is defined: no need to re-create a default value if we
      --  already have one.

      if not Result.Is_Defined and then PRA_Def.Has_Default_In (Self.Kind) then
         --  Finally use the default value if defined

         declare
            use type PRA.Value_Kind;
            use type PRA.Default_Value_Kind;
            package SR renames Source_Reference;

            Default : PRA.Default_Value renames PRA_Def.Default;

         begin
            case Default.Kind is
               when PRA.D_Attribute_Reference =>
                  declare
                     Project_SRef : constant SR.Object :=
                                      SR.Object
                                        (SR.Create (Self.Path_Name.Value,
                                         0, 0));
                     Attr_Name    : constant SR.Attribute.Object :=
                                      SR.Attribute.Object
                                        (SR.Attribute.Create
                                           (Project_SRef, Name));

                     --  ??? Separate_Suffix has no index and defaults to an
                     --  indexed attribute. We need some way to show that in
                     --  the attribute definition. In the mean time, let's
                     --  hardcode this behavior.

                     Ref          : constant Project.Attribute.Object :=
                                      Self.Attribute
                                        (Name   => Default.Attr,
                                         Pack   => Pack,
                                         Index  =>
                                           (if Name = PRA.Separate_Suffix
                                            then Attribute_Index.Create
                                              (Ada_Language)
                                            else Index),
                                         At_Pos => At_Pos);
                  begin
                     if Ref.Is_Defined then
                        Result := Ref.Rename (Attr_Name);

                        --  See note above about Separate_Suffix...
                        if Name = PRA.Separate_Suffix then
                           Result.Set_Index (Attribute_Index.Undefined);
                        end if;
                     end if;
                  end;

               when PRA.D_Value =>
                  --  Retrieve the value. Note that not all indexes may be
                  --  referenced here, so we can still return the Undefined
                  --  attribute.
                  declare
                     Def_Index : Value_Type renames Get_Default_Index;
                  begin
                     if PRA.Exists (Default.Values, Def_Index) then
                        Result := Project.Attribute.Create
                          (Name    => Name,
                           Index   => Index,
                           Source  => Self.Path_Name,
                           Default => PRA.Get (Default.Values, Def_Index),
                           As_List => PRA_Def.Value /= PRA.Single);
                        Result.Set_Case (PRA_Def.Value_Case_Sensitive);
                     end if;
                  end;

               when PRA.D_Callback =>
                  --  Create the default value for the attribute from a
                  --  callback call.

                  Result := Project.Attribute.Create
                    (Name    => Name,
                     Index   => Index,
                     Source  => Self.Path_Name,
                     Default => Default.Callback (Self),
                     As_List => PRA_Def.Value /= PRA.Single);
                  Result.Set_Case (PRA_Def.Value_Case_Sensitive);
            end case;
         end;
      end if;

      if Alias /= No_Attribute
        and then Result.Is_Defined
        and then Result.Name.Id = Alias
      then
         --  We found the alternative name for the attribute. Let's rename
         --  it to the requested name.
         Result := GPR2.Project.Attribute.Get_Alias (Result, Name);
      end if;

      if PRA_Def.Value_Is_Set and then Result.Is_Defined then
         Result.Ensure_Set;
      end if;

      --  Finally return the result
      Definition.Get_RO (Self).Cache.Update_Cache
         (Name   => Name,
          Pkg    => Pack,
          Index  => Index,
          At_Pos => At_Pos,
          Attr   => Result);
      return Result;
   end Attribute;

   ------------------------
   -- Attribute_Location --
   ------------------------

   function Attribute_Location
     (Self  : Object;
      Name  : Attribute_Id;
      Index : Attribute_Index.Object := Attribute_Index.Undefined;
      Pack  : Optional_Package_Id    := No_Package)
      return Source_Reference.Object'Class
   is
      Attr : Project.Attribute.Object;
   begin
      Attr := Self.Attribute (Name, Pack, Index => Index);

      if Attr.Is_Defined then
         return Attr;
      else
         return Source_Reference.Create (Self.Path_Name.Value, 0, 0);
      end if;
   end Attribute_Location;

   ----------------
   -- Attributes --
   ----------------

   function Attributes
     (Self          : Object;
      Name          : Attribute_Id;
      With_Defaults : Boolean := True;
      With_Config   : Boolean := True)
      return Project.Attribute.Set.Object is
   begin
      return Attributes_Internal
        (Self, No_Package, Name, With_Defaults, With_Config);
   end Attributes;

   function Attributes
     (Self          : Object;
      Pack          : Package_Id;
      Name          : Attribute_Id;
      With_Defaults : Boolean := True;
      With_Config   : Boolean := True)
      return Project.Attribute.Set.Object is
   begin
      return Attributes_Internal
        (Self, Pack, Name, With_Defaults, With_Config);
   end Attributes;

   function Attributes
     (Self          : Object;
      Pack          : Optional_Package_Id    := No_Package;
      With_Defaults : Boolean                := True;
      With_Config   : Boolean                := True)
      return Project.Attribute.Set.Object
   is
      Result : Project.Attribute.Set.Object;
   begin
      for Attr_Id of PRA.All_Attributes (Pack) loop
         for Attr of Self.Attributes_Internal
           (Pack          => Pack,
            Name          => Attr_Id,
            With_Defaults => With_Defaults,
            With_Config   => With_Config)
         loop
            --  Do not include alias values, as they would duplicate their
            --  aliased attribute.
            if not Attr.Is_Alias then
               Result.Insert (Attr);
            end if;
         end loop;
      end loop;

      return Result;
   end Attributes;

   -------------------------
   -- Attributes_Internal --
   -------------------------

   function Attributes_Internal
     (Self          : Object;
      Pack          : Optional_Package_Id;
      Name          : Attribute_Id;
      With_Defaults : Boolean := True;
      With_Config   : Boolean := True)
      return Project.Attribute.Set.Object
   is
      Q_Name : constant PRA.Qualified_Name    := PRA.Create (Name, Pack);
      Alias  : constant Optional_Attribute_Id := PRA.Alias (Q_Name).Attr;
      Def    : constant PRA.Def               := PRA.Get (Q_Name);
      Result : Project.Attribute.Set.Object;

      use type PRA.Inherit_From_Extended_Type;
      use type PRA.Index_Value_Type;

      procedure Add_Attr (Attr   : Project.Attribute.Object;
                          Concat : Boolean);

      function Config return Object is
        (Self.Tree.Configuration.Corresponding_View);
      --  Configuration View. To be used only when the tree has a configuration

      --------------
      -- Add_Attr --
      --------------

      procedure Add_Attr
        (Attr   : Project.Attribute.Object;
         Concat : Boolean)
      is
         Cursor : constant GPR2.Project.Attribute.Set.Cursor :=
                    Result.Find (Name, Attr.Index);
      begin
         --  Check if we already have the same attribute in the main view

         if not Project.Attribute.Set.Has_Element (Cursor) then
            --  Nope, so just inherit
            Result.Insert (Attr);

         elsif Concat then
            --  If we have it, and we need to concatenate, then amend the
            --  value in Result.

            declare
               New_Attr : Project.Attribute.Object :=
                            Project.Attribute.Set.Element (Cursor);
            begin
               New_Attr.Prepend_Vector (Attr);
               Result.Include (New_Attr);
            end;
         end if;
      end Add_Attr;

   begin
      --  If the attribute has no index, then just call Attribute, as at most
      --  one result can be returned,

      if Def.Index_Type = PRA.No_Index then
         declare
            Attr : constant Project.Attribute.Object :=
                     Self.Attribute (Name, Pack);
         begin
            if Attr.Is_Defined
              and then (With_Defaults or else not Attr.Is_Default)
              and then (With_Config or else not Attr.Is_From_Config)
            then
               Result.Include (Attr);
            end if;

            return Result;
         end;
      end if;

      if Pack = No_Package then
         Result := Get_RO (Self).Attrs.Filter (Name);

         if Alias /= No_Attribute then
            for Attr of Get_RO (Self).Attrs.Filter (Alias) loop
               --  Return the attributes with the requested name

               if not Result.Contains (Name, Attr.Index) then
                  Result.Include (Attr.Get_Alias (Name));
               end if;
            end loop;
         end if;

         --  Query extended views

         if Def.Inherit_From_Extended /= PRA.Not_Inherited
           and then Self.Is_Extending
         then
            for Attr of Self.Extended_Root.Attributes_Internal
              (No_Package, Name, False, False)
            loop
               Add_Attr (Attr, Def.Inherit_From_Extended = PRA.Concatenated);
            end loop;
         end if;

      else
         declare
            --  Self.Pack resolves inheritance
            Pack_Inst : Project.Pack.Object renames Self.Pack (Pack);
         begin
            if not Pack_Inst.Attrs.Is_Empty then
               Result := Pack_Inst.Attrs.Filter (Name);

               if Alias /= No_Attribute then
                  for Attr of Pack_Inst.Attrs.Filter (Alias) loop
                     if not Result.Contains (Name, Attr.Index) then
                        Result.Insert (Attr.Get_Alias (Name));
                     end if;
                  end loop;
               end if;
            end if;
         end;
      end if;

      --  Query configuration project

      if With_Config
        and then Self.Tree.Has_Configuration
      then
         for Attr of
           Config.Attributes_Internal (Pack, Name, False, False)
         loop
            Add_Attr (Attr, Def.Config_Concatenable);
         end loop;
      end if;

      --  Finally check the default value

      if With_Defaults
        and then Def.Has_Default_In (Self.Kind)
      then
         declare
            use GPR2.Project.Attribute.Set;

            Cursor : GPR2.Project.Attribute.Set.Cursor;
            Attr   : Project.Attribute.Object;
         begin
            case Def.Default.Kind is
               when PRA.D_Callback =>
                  null;

               when PRA.D_Attribute_Reference =>
                  for Attr of Self.Attributes_Internal (Pack, Def.Default.Attr)
                  loop
                     Cursor := Result.Find (Name, Attr.Index);

                     if not Has_Element (Cursor) then
                        Result.Insert
                          (Attr.Rename
                             (GPR2.Source_Reference.Attribute.Object
                                  (GPR2.Source_Reference.Attribute.Create
                                       (GPR2.Source_Reference.Builtin,
                                        Name))));
                     end if;
                  end loop;

               when PRA.D_Value =>
                  for C in Def.Default.Values.Iterate loop
                     declare
                        Val_Index  : constant Value_Type :=
                                       PRA.Value_Map.Key (C);
                        Attr_Index : Attribute_Index.Object;
                     begin
                        if Val_Index /= PRA.Any_Index
                          and then Val_Index'Length > 0
                        then
                           Attr_Index := Attribute_Index.Create (Val_Index);
                           Attr_Index.Set_Case
                             (PRA.Is_Case_Sensitive
                                (Val_Index, Def.Index_Type));

                           Cursor := Result.Find (Name, Attr_Index);

                           if not Has_Element (Cursor) then
                              --  Create the value
                              Attr := Project.Attribute.Create
                                (Name    => Source_Reference.Attribute.Object
                                             (Source_Reference.Attribute.Create
                                               (Source_Reference.Builtin,
                                                Name)),
                                 Index   => Attr_Index,
                                 Value   => Source_Reference.Value.Object
                                              (Source_Reference.Value.Create
                                                (Source_Reference.Builtin,
                                                 PRA.Value_Map.Element (C))),
                                 Default => True);
                              Attr.Set_Case (Def.Value_Case_Sensitive);
                              Result.Insert (Attr);
                           end if;
                        end if;
                     end;
                  end loop;
            end case;
         end;
      end if;

      return Result;
   end Attributes_Internal;

   ----------------------
   -- Binder_Artifacts --
   ----------------------

   function Binder_Artifacts
     (Self     : Object;
      Name     : Simple_Name;
      Language : Language_Id := No_Language)
      return GPR2.Path_Name.Set.Object
   is
      use Ada.Text_IO;
      use GNATCOLL.Utils;

      Result  : GPR2.Path_Name.Set.Object;
      Obj_Dir : constant GPR2.Path_Name.Object := Self.Object_Directory;
      BP      : constant Filename_Optional :=
                  (if Language = No_Language then No_Filename
                   else Self.Binder_Prefix (Language));
      BF      : constant GPR2.Path_Name.Object :=
                  Obj_Dir.Compose
                    (BP & Name
                     & (if Self.Is_Library then ".lexch" else ".bexch"));

      File    : File_Type;
      Obj_Ext : constant Filename_Optional :=
                  (if Language = No_Language then No_Filename
                   else Self.Tree.Object_Suffix (Language));

      Generated : Boolean := False;
      Gen_Src   : Boolean := False;

   begin
      if GNAT.OS_Lib.Is_Regular_File (BF.Value) then
         Open (File, Mode => In_File, Name => BF.Value);

         while not End_Of_File (File) loop
            declare
               Line : constant String := Get_Line (File);
            begin
               if Line (Line'First) = '[' then
                  Generated := Starts_With (Line, "[GENERATED ");
                  if Generated then
                     Gen_Src := Line = "[GENERATED SOURCE FILES]";
                  end if;

               elsif Generated then
                  Result.Append (Obj_Dir.Compose (Filename_Type (Line)));

                  if Gen_Src and then Self.Has_Languages then
                     for L of Self.Languages loop
                        declare
                           A : constant Project.Attribute.Object :=
                                 Self.Attribute
                                   (PRA.Body_Suffix,
                                    PRP.Naming,
                                    Attribute_Index.Create (L.Text));
                        begin
                           if A.Is_Defined
                             and then Ends_With (Line, A.Value.Text)
                           then
                              for E of Self.Source_Artifact_Extensions
                                (Language => +Name_Type (L.Text))
                              loop
                                 Result.Append
                                   (Obj_Dir.Compose
                                      (Filename_Type (Line & E)));
                              end loop;
                           end if;
                        end;
                     end loop;

                  elsif Obj_Ext /= ""
                    and then Ends_With (Line, String (Obj_Ext))
                  then
                     for E of Self.Object_Artifact_Extensions (Language) loop
                        Result.Append
                          (Obj_Dir.Compose
                             (Filename_Type
                                (Line (Line'First
                                       .. Line'Last - Obj_Ext'Length) & E)));
                     end loop;
                  end if;
               end if;
            end;
         end loop;

         Close (File);
         Result.Append (BF);
      end if;

      return Result;
   end Binder_Artifacts;

   -------------------
   -- Binder_Prefix --
   -------------------

   function Binder_Prefix
     (Self : Object; Language : Language_Id) return Filename_Optional
   is
      Index : constant Attribute_Index.Object :=
                Attribute_Index.Create (Value_Type (Name (Language)));
   begin
      return Filename_Optional
        (Self.Attribute (PRA.Prefix, PRP.Binder, Index).Value.Text);
   end Binder_Prefix;

   ---------------------
   -- Check_Attribute --
   ---------------------

   function Check_Attribute
     (Self   : Object;
      Name   : Attribute_Id;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Unit_Index             := No_Index;
      Result : out Project.Attribute.Object) return Boolean is
   begin
      Result := Self.Attribute (Name, No_Package, Index, At_Pos);
      return Result.Is_Defined;
   exception
      when Attribute_Error =>
         Result := Project.Attribute.Undefined;
         return False;
   end Check_Attribute;

   function Check_Attribute
     (Self   : Object;
      Pack   : Package_Id;
      Name   : Attribute_Id;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Unit_Index             := No_Index;
      Result : out Project.Attribute.Object) return Boolean is
   begin
      Result := Self.Attribute (Name, Pack, Index, At_Pos);
      return Result.Is_Defined;
   exception
      when Attribute_Error =>
         Result := Project.Attribute.Undefined;
         return False;
   end Check_Attribute;

   ------------------
   -- Check_Parent --
   ------------------

   function Check_Parent (Self : Object; Parent : out Object) return Boolean is
      use Ada.Strings;

      Ref  : constant Definition.Const_Ref := Definition.Get_RO (Self);
      Name : constant Name_Type := Ref.Trees.Project.Name;
      Dot  : constant Natural := Fixed.Index (String (Name), ".", Backward);
   begin
      if Dot > 0 then
         Parent := Ref.Imports (Name (Name'First .. Dot - 1));
         return True;
      end if;

      return False;
   end Check_Parent;

   ------------------
   -- Check_Source --
   ------------------

   function Check_Source
     (Self     : Object;
      Filename : GPR2.Simple_Name;
      Result   : in out Project.Source.Object) return Boolean is
   begin
      return Definition.Check_Source (Self, Filename, Result);
   end Check_Source;

   --------------------------
   -- Clean_Attribute_List --
   --------------------------

   function Clean_Attribute_List
     (Self     : Object;
      Name     : Attribute_Id;
      Language : Language_Id) return Containers.Value_Set
   is
      Index  : constant Attribute_Index.Object :=
                 (if Language = No_Language
                  then Attribute_Index.Undefined
                  else Attribute_Index.Create
                    (Value_Type (GPR2.Name (Language))));
      Attr   : constant Project.Attribute.Object :=
                 Self.Attribute (Name, PRP.Clean, Index);
      Result : Containers.Value_Set;

   begin
      if Attr.Is_Defined then
         for Val of Attr.Values loop
            Result.Include (Val.Text);
         end loop;
      end if;

      return Result;
   end Clean_Attribute_List;

   -------------
   -- Context --
   -------------

   function Context (Self : Object) return GPR2.Context.Object is
   begin
      return Definition.Get_Context (Self);
   end Context;

   function Context (Self : Object) return Context_Kind is
   begin
      return Definition.Get_RO (Self).Context;
   end Context;

   ----------------
   -- Executable --
   ----------------

   function Executable
     (Self   : Object;
      Source : Simple_Name;
      At_Pos : Unit_Index) return GPR2.Path_Name.Object
   is
      BN       : constant  Value_Not_Empty :=
                   Remove_Body_Suffix (Self, Source);
      BN_Index : constant Attribute_Index.Object :=
                   Attribute_Index.Create (BN);
      Index    : constant Attribute_Index.Object :=
                   Attribute_Index.Create (Value_Not_Empty (Source));
      Attr     : GPR2.Project.Attribute.Object;

      function Executable
        (Base_Name : Value_Not_Empty) return GPR2.Path_Name.Object
      is (GPR2.Path_Name.Create_File
          (Filename_Type (Base_Name) & Self.Executable_Suffix,
           Filename_Optional (Self.Executable_Directory.Dir_Name)));
      --  Full executable path for base name

   begin
      if (Self.Check_Attribute
            (PRP.Builder, PRA.Executable, Index, At_Pos, Attr)
          or else
            (Source /= Simple_Name (BN)
             and then Self.Check_Attribute
               (PRP.Builder, PRA.Executable, BN_Index, At_Pos, Attr)))
        and then At_Pos = At_Pos_Or (Attr.Index, 0)
      then
         return Executable (Attr.Value.Text);
      else
         return Executable (BN);
      end if;
   end Executable;

   --------------------------
   -- Executable_Directory --
   --------------------------

   function Executable_Directory
     (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Self.Apply_Root_And_Subdirs (PRA.Exec_Dir);
   end Executable_Directory;

   -----------------------
   -- Executable_Suffix --
   -----------------------

   function Executable_Suffix (Self : Object) return Filename_Optional is
   begin
      return Filename_Optional (Self.Attribute
        (PRA.Executable_Suffix, Pack => PRP.Builder).Value.Text);
   end Executable_Suffix;

   -----------------
   -- Executables --
   -----------------

   function Executables (Self : Object) return GPR2.Path_Name.Set.Object is
      Attr : constant Project.Attribute.Object := Self.Attribute (PRA.Main);
   begin
      return Set : GPR2.Path_Name.Set.Object do
         if Attr.Is_Defined then
            for Main of Attr.Values loop
               Set.Append (Self.Executable (Simple_Name (Main.Text),
                           At_Pos_Or (Main, 0)));
            end loop;
         end if;
      end return;
   end Executables;

   --------------
   -- Extended --
   --------------

   function Extended (Self : Object) return Set.Object is
   begin
      return Definition.Get_RO (Self).Extended;
   end Extended;

   -------------------
   -- Extended_Root --
   -------------------

   function Extended_Root (Self : Object) return Object is
   begin
      return Definition.Get_RO (Self).Extended_Root;
   end Extended_Root;

   ---------------
   -- Extending --
   ---------------

   function Extending (Self : Object) return Object is
   begin
      return Definition.Strong (Definition.Get_RO (Self).Extending);
   end Extending;

   -------------
   -- Foreach --
   -------------

   procedure Foreach
     (Self              : Object;
      Directory_Pattern : GPR2.Filename_Optional;
      Source            : GPR2.Source_Reference.Value.Object;
      File_CB           : not null access procedure
                            (File : GPR2.Path_Name.Object);
      Directory_CB      : access procedure
                            (Directory       : GPR2.Path_Name.Object;
                             Is_Root_Dir     : Boolean;
                             Do_Dir_Visit    : in out Boolean;
                             Do_Subdir_Visit : in out Boolean) := null)
   is
      use GNAT.OS_Lib;
      use GNATCOLL.Utils;

      View_Dir  : constant GPR2.Path_Name.Object :=
                    GPR2.Path_Name.Create_Directory
                      (Filename_Optional (Self.Path_Name.Dir_Name));
      Dir       : constant String :=
                    (if Directory_Pattern'Length = 0
                     then "."
                     else
                       (if Directory_Pattern = "**"
                        then "./**"
                        else String (Directory_Pattern)));
      --  normalize dir part avoiding "" & "**"
      Recursive : constant Boolean :=
                    Dir'Length > 2
                    and then Dir (Dir'Last - 1 .. Dir'Last) = "**"
                    and then Is_Directory_Separator (Dir (Dir'Last - 2));
      Last      : constant Positive :=
                    Dir'Last - (if Recursive then 2 else 0);
      Root_Dir  : constant String :=
                    (if Is_Absolute_Path (Dir)
                     then Dir (Dir'First .. Last)
                     else View_Dir.Compose
                       (Filename_Optional (Dir (Dir'First .. Last))).Value);

      procedure Handle_Directory
        (Dir         : Filename_Type;
         Recursive   : Boolean;
         Is_Root_Dir : Boolean := False);
      --  Handle the specified directory, that is read all files in Dir and
      --  eventually call recursivelly Handle_Directory if a recursive read
      --  is specified.

      ----------------------
      -- Handle_Directory --
      ----------------------

      procedure Handle_Directory
        (Dir         : Filename_Type;
         Recursive   : Boolean;
         Is_Root_Dir : Boolean := False)
      is
         use all type Directories.File_Kind;

         Dir_Search      : Directories.Search_Type;
         Dir_Entry       : Directories.Directory_Entry_Type;
         Do_Dir_Visit    : Boolean := True;
         Do_Subdir_Visit : Boolean := Recursive;
      begin
         if Directory_CB /= null then
            Directory_CB
              (GPR2.Path_Name.Create_Directory
                 (Dir, GPR2.Path_Name.No_Resolution),
               Is_Root_Dir,
               Do_Dir_Visit,
               Do_Subdir_Visit);
         end if;

         if Do_Dir_Visit or else Do_Subdir_Visit then
            Directories.Start_Search
              (Dir_Search, String (Dir), "",
               Filter => (Directory     => Do_Subdir_Visit,
                          Ordinary_File => Do_Dir_Visit,
                          Special_File  => False));

            while Directories.More_Entries (Dir_Search) loop
               Directories.Get_Next_Entry (Dir_Search, Dir_Entry);

               case Directories.Kind (Dir_Entry) is
                  when Ordinary_File =>
                     File_CB
                       (GPR2.Path_Name.Create_File
                          (Filename_Optional
                               (Directories.Full_Name (Dir_Entry)),
                           GPR2.Path_Name.No_Resolution));

                  when Directory =>
                     if Directories.Simple_Name (Dir_Entry) not in "." | ".."
                     then
                        Handle_Directory
                          (Filename_Type (Directories.Full_Name (Dir_Entry)),
                           Do_Subdir_Visit);
                     end if;

                  when Special_File =>
                     raise Program_Error;
               end case;
            end loop;

            Directories.End_Search (Dir_Search);
         end if;
      exception
         when Ada.IO_Exceptions.Name_Error =>
            Self.Tree.Append_Message
              (GPR2.Message.Create
                 (GPR2.Message.Error,
                  """" & String (Dir) & """ is not a valid directory",
                  Source));
      end Handle_Directory;

   begin
      Handle_Directory
        (Filename_Type (Root_Dir),
         Recursive   => Recursive,
         Is_Root_Dir => True);
   end Foreach;

   ---------------------------
   -- Has_Aggregate_Context --
   ---------------------------

   function Has_Aggregate_Context (Self : Object) return Boolean is
   begin
      return Definition.Get_RO (Self).Context = Aggregate;
   end Has_Aggregate_Context;

   -------------------
   -- Has_Attribute --
   -------------------

   function Has_Attribute
     (Self   : Object;
      Name   : Attribute_Id;
      Pack   : Optional_Package_Id    := No_Package;
      Index  : Attribute_Index.Object := Attribute_Index.Undefined;
      At_Pos : Unit_Index             := No_Index) return Boolean is
   begin
      return Self.Attribute (Name, Pack, Index, At_Pos).Is_Defined;
   exception
      when Attribute_Error =>
         return False;
   end Has_Attribute;

   -----------------
   -- Has_Context --
   -----------------

   function Has_Context (Self : Object) return Boolean is
   begin
      return not Definition.Get_Context (Self).Is_Empty;
   end Has_Context;

   -----------------
   -- Has_Imports --
   -----------------

   function Has_Imports (Self : Object) return Boolean is
   begin
      return not Definition.Get_RO (Self).Trees.Imports.Is_Empty;
   end Has_Imports;

   ------------------
   -- Has_Language --
   ------------------

   function Has_Language (Self : Object; Name : Name_Type) return Boolean is
      Lang_Attr : GPR2.Project.Attribute.Object;
   begin
      Lang_Attr := Self.Attribute (PRA.Languages);
      if Lang_Attr.Is_Defined then
         for Val of Lang_Attr.Values loop
            if Name_Type (Val.Text) = Name then
               return True;
            end if;
         end loop;
      end if;

      return False;
   end Has_Language;

   -------------------
   -- Has_Languages --
   -------------------

   function Has_Languages (Self : Object) return Boolean is
   begin
      return Self.Has_Attribute (PRA.Languages);
   end Has_Languages;

   ---------------
   -- Has_Mains --
   ---------------

   function Has_Mains (Self : Object) return Boolean is
      Attr : constant Project.Attribute.Object :=
               Self.Attribute (PRA.Main);
   begin
      if not Attr.Is_Defined then
         return False;
      else
         return Attr.Count_Values > 0;
      end if;
   end Has_Mains;

   -----------------
   -- Has_Package --
   -----------------

   function Has_Package
     (Self           : Object;
      Name           : Package_Id;
      Check_Extended : Boolean := True;
      With_Defaults  : Boolean := True;
      With_Config    : Boolean := True) return Boolean
   is
      View        : Object := Self;
      Def         : GPR2.Project.Registry.Attribute.Default_Rules;
      Has_Default : Boolean := False;

      procedure For_Rule (Attribute : Attribute_Id; Definition : PRA.Def);
      --  Check if the definition applies to Name in Self's context

      --------------
      -- For_Rule --
      --------------

      procedure For_Rule (Attribute : Attribute_Id; Definition : PRA.Def) is
         pragma Unreferenced (Attribute);
      begin
         if not Has_Default
           and then Definition.Is_Allowed_In (Self.Kind)
           and then Definition.Has_Default_In (Self.Kind)
         then
            Has_Default := True;
         end if;
      end For_Rule;

   begin
      if Definition.Get_RO (Self).Has_Packages (Name) then
         return True;
      end if;

      if With_Config
        and then Self.Tree.Has_Configuration
        and then Self.Tree.Configuration.Corresponding_View.
                   Get_RO.Has_Packages (Name)
      then
         return True;
      end if;

      --  Check if the package has default values

      if With_Defaults then
         Def := PRA.Get_Default_Rules (Name);

         --  Check if we can create a default value for package Name

         PRA.For_Each_Default (Def, For_Rule'Access);

         if Has_Default then
            return True;
         end if;
      end if;

      --  Finally, check extended

      loop
         exit when not Check_Extended or else not View.Is_Extending;

         View := View.Extended_Root;

         if Definition.Get_RO (View).Has_Packages (Name) then
            return True;
         end if;
      end loop;

      --  Should also check configuration ???

      return False;
   end Has_Package;

   ----------------
   -- Has_Source --
   ----------------

   function Has_Source
     (Self : Object; Filename : GPR2.Simple_Name) return Boolean is
   begin
      return Definition.Has_Source (Self, Filename);
   end Has_Source;

   -----------------------------
   -- Has_Source_Subdirectory --
   -----------------------------

   function Has_Source_Subdirectory (Self : Object) return Boolean is
   begin
      return Self.Tree.all.Has_Src_Subdirs;
   end Has_Source_Subdirectory;

   -----------------
   -- Has_Sources --
   -----------------

   function Has_Sources (Self : Object) return Boolean is
      S : constant Project.Source.Set.Object := Self.Sources with Unreferenced;
      --  Let's compute the set of sources to be able to get the right answer
      --  below. Remember the sources are cached and computed only when
      --  requested.
   begin
      return not Definition.Get_RO (Self).Sources.Is_Empty;
   end Has_Sources;

   ---------------
   -- Has_Types --
   ---------------

   function Has_Types
     (Self : Object;
      Name : Optional_Name_Type := No_Name) return Boolean is
   begin
      return Definition.Get_RO (Self).Has_Types (Name);
   end Has_Types;

   -------------------
   -- Has_Variables --
   -------------------

   function Has_Variables
     (Self : Object;
      Name : Optional_Name_Type := No_Name) return Boolean is
   begin
      if Name = No_Name then
         return not Definition.Get_RO (Self).Vars.Is_Empty;
      else
         return Definition.Get_RO (Self).Vars.Contains (Name);
      end if;
   end Has_Variables;

   function Has_Variables
     (Self : Object;
      Pack : Package_Id;
      Name : Optional_Name_Type := No_Name) return Boolean is
   begin
      if not Self.Has_Package (Pack,
                               With_Defaults => False,
                               With_Config   => False)
      then
         return False;
      end if;

      if Name = No_Name then
         return not Self.Pack (Pack).Vars.Is_Empty;
      else
         return Self.Pack (Pack).Vars.Contains (Name);
      end if;
   end Has_Variables;

   --------------------
   -- Hide_Unit_Body --
   --------------------

   procedure Hide_Unit_Body (Self : Object; Unit : Name_Type) is
      Ref : constant Definition.Ref := Definition.Get (Self);
      CU  : constant Unit_Info.Set.Cursor := Ref.Units.Find (Unit);
   begin
      if Unit_Info.Set.Set.Has_Element (CU) then
         Ref.Units (CU).Remove_Body;
      end if;
   end Hide_Unit_Body;

   --------
   -- Id --
   --------

   function Id (Self : Object) return GPR2.View_Ids.View_Id is
   begin
      return Definition.Get_RO (Self).Unique_Id;
   end Id;

   -------------
   -- Imports --
   -------------

   function Imports
     (Self : Object; Recursive : Boolean := False) return Set.Object
   is
      Result : GPR2.Project.View.Set.Object;

      procedure Add (Self : Object);
      --  Add Self imported projects

      ---------
      -- Add --
      ---------

      procedure Add (Self : Object) is
         Position : Set.Set.Cursor;
         Inserted : Boolean;
      begin
         for Import of Definition.Get_RO (Self).Imports loop
            Result.Insert (Import, Position, Inserted);

            if Inserted and then Recursive then
               Add (Import);
            end if;
         end loop;
      end Add;

   begin
      Add (Self);
      return Result;
   end Imports;

   ------------------------
   -- Invalidate_Sources --
   ------------------------

   procedure Invalidate_Sources (Self : in out Object) is
   begin
      Definition.Get_RW (Self).Sources_Signature :=
        GPR2.Context.Default_Signature;
   end Invalidate_Sources;

   ------------------------------
   -- Is_Aggregated_In_Library --
   ------------------------------

   function Is_Aggregated_In_Library (Self : Object) return Boolean is
      Ref : constant Definition.Const_Ref := Definition.Get_RO (Self);
   begin

      return not Ref.Agg_Libraries.Is_Empty;
   end Is_Aggregated_In_Library;

   -----------------
   -- Is_Extended --
   -----------------

   function Is_Extended (Self : Object) return Boolean is
      use Definition_References;
   begin
      return Definition.Get_RO (Self).Extending /= Null_Weak_Ref;
   end Is_Extended;

   --------------------
   -- Is_Extended_By --
   --------------------

   function Is_Extended_By (Self : Object; View : Object) return Boolean is
   begin
      return View.Is_Extension_Of (Self);
   end Is_Extended_By;

   ------------------
   -- Is_Extending --
   ------------------

   function Is_Extending
     (Self : Object; Parent : Object'Class := Undefined) return Boolean
   is
      Def : constant Definition.Const_Ref := Definition.Get_RO (Self);
   begin
      if not Def.Extended_Root.Is_Defined then
         return False;
      end if;

      if not Parent.Is_Defined then
         return True;
      end if;

      for Ext of Self.Extended loop
         if Ext = Object (Parent) then
            return True;
         end if;

         if Ext.Is_Extending then
            if Is_Extending (Ext, Parent) then
               return True;
            end if;
         end if;
      end loop;

      return False;
   end Is_Extending;

   ----------------------
   -- Is_Extending_All --
   ----------------------

   function Is_Extending_All (Self : Object) return Boolean is
   begin
      return Definition.Get_RO (Self).Trees.Project.Is_Extending_All;
   end Is_Extending_All;

   ---------------------
   -- Is_Extension_Of --
   ---------------------

   function Is_Extension_Of (Self : Object; View : Object) return Boolean is
      use GPR2.View_Ids;
   begin
      if Self.Id = View.Id then
         return True;
      elsif not Self.Is_Extending then
         return False;
      else
         return View.Is_Extending (Self);
      end if;
   end Is_Extension_Of;

   -------------------------
   -- Is_Externally_Built --
   -------------------------

   function Is_Externally_Built (Self : Object) return Boolean is
      Attr : constant Project.Attribute.Object :=
               Self.Attribute
                 (Project.Registry.Attribute.Externally_Built);
   begin
      return Attr.Is_Defined and then Attr.Value_Equal ("true");
   end Is_Externally_Built;

   -------------
   -- Is_Main --
   -------------

   function Is_Main
     (Self : Object; Source : Project.Source.Object) return Boolean
   is
      Path  : constant GPR2.Path_Name.Object := Source.Path_Name;
      Mains : constant Project.Attribute.Object :=
                Self.Attribute (Registry.Attribute.Main);
   begin
      return Mains.Is_Defined
        and then
          (Mains.Has_Value (Value_Type (Path.Base_Name))
           or else Mains.Has_Value (Value_Type (Path.Simple_Name)));
   end Is_Main;

   ----------------
   -- Is_Runtime --
   ----------------

   function Is_Runtime (Self : Object) return Boolean is
      Tree : constant not null access Project.Tree.Object := Self.Tree;
   begin
      return Tree.Has_Runtime_Project and then Tree.Runtime_Project = Self;
   end Is_Runtime;

   -----------------------
   -- Is_Shared_Library --
   -----------------------

   function Is_Shared_Library (Self : Object) return Boolean is
      LK : constant Name_Type := Self.Library_Kind;
   begin
      return LK = "dynamic" or else LK = "relocatable";
   end Is_Shared_Library;

   -----------------------
   -- Is_Static_Library --
   -----------------------

   function Is_Static_Library (Self : Object) return Boolean is
      LK : constant Name_Type := Self.Library_Kind;
   begin
      return LK = "static" or else LK = "static-pic";
   end Is_Static_Library;

   ----------
   -- Kind --
   ----------

   function Kind (Self : Object) return Project_Kind is
   begin
      return Definition.Get_RO (Self).Kind;
   end Kind;

   ---------------
   -- Languages --
   ---------------

   function Languages (Self : Object) return Containers.Source_Value_List is
      Attr : constant GPR2.Project.Attribute.Object :=
               Self.Attribute (PRA.Languages);
   begin
      if Attr.Is_Defined then
         return Attr.Values;
      else
         return Containers.Source_Value_Type_List.Empty;
      end if;
   end Languages;

   ---------------------------
   -- Library_Ali_Directory --
   ---------------------------

   function Library_Ali_Directory
     (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Self.Apply_Root_And_Subdirs (PRA.Library_Ali_Dir);
   end Library_Ali_Directory;

   -----------------------
   -- Library_Directory --
   -----------------------

   function Library_Directory (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Self.Apply_Root_And_Subdirs (PRA.Library_Dir);
   end Library_Directory;

   ----------------------
   -- Library_Filename --
   ----------------------

   function Library_Filename (Self : Object) return GPR2.Path_Name.Object is
      File_Name : Unbounded_String;
   begin
      --  Library prefix

      Append
        (File_Name, Self.Attribute
           (PRA.Shared_Library_Prefix).Value.Text);

      --  Library name

      Append (File_Name, Self.Attribute (PRA.Library_Name).Value.Text);

      --  Library suffix

      if Self.Is_Static_Library then
         Append (File_Name, String (Self.Tree.Archive_Suffix));

      else
         Append
           (File_Name,
            String (Self.Attribute (PRA.Shared_Library_Suffix).Value.Text));
      end if;

      return GPR2.Path_Name.Create_File
        (Filename_Type (To_String (File_Name)),
         Directory => Filename_Optional (Self.Library_Directory.Dir_Name));
   end Library_Filename;

   ------------------
   -- Library_Kind --
   ------------------

   function Library_Kind (Self : Object) return Name_Type is
      Attr : constant Project.Attribute.Object :=
               Self.Attribute (PRA.Library_Kind);
   begin
      return Name_Type (Attr.Value.Text);
   end Library_Kind;

   --------------------------------
   -- Library_Major_Version_Name --
   --------------------------------

   function Library_Major_Version_Filename
     (Self : Object) return GPR2.Path_Name.Object
   is

      function Major_Version_Name
        (Lib_Version : Filename_Type) return Filename_Type;
      --  Returns the major version name

      ------------------------
      -- Major_Version_Name --
      ------------------------

      function Major_Version_Name
        (Lib_Version : Filename_Type) return Filename_Type is
      begin
         for J in reverse Lib_Version'Range loop
            if Lib_Version (J) = '.' then
               return Lib_Version (Lib_Version'First .. J - 1);
            end if;
         end loop;

         --  Impossible if project view was validated just after parse

         raise Program_Error with "cannot get major version";
      end Major_Version_Name;

      LV : constant Project.Attribute.Object :=
             Self.Attribute (PRA.Library_Version);

   begin
      return GPR2.Path_Name.Create_File
        (Major_Version_Name (Filename_Type (LV.Value.Text)),
         Directory => Filename_Optional (Self.Library_Filename.Dir_Name));
   end Library_Major_Version_Filename;

   ---------------------------
   -- Library_Src_Directory --
   ---------------------------

   function Library_Src_Directory
     (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Self.Apply_Root_And_Subdirs (PRA.Library_Src_Dir);
   end Library_Src_Directory;

   ------------------------
   -- Library_Standalone --
   ------------------------

   function Library_Standalone
     (Self : Object) return Standalone_Library_Kind
   is
      Attr : constant Project.Attribute.Object :=
               Self.Attribute (PRA.Library_Standalone);
   begin
      return Standalone_Library_Kind'Value (Attr.Value.Text);
   end Library_Standalone;

   ------------------------------
   -- Library_Version_Filename --
   ------------------------------

   function Library_Version_Filename
     (Self : Object) return GPR2.Path_Name.Object is
   begin
      return GPR2.Path_Name.Create_File
        (Filename_Type (Self.Attribute (PRA.Library_Version).Value.Text),
         Directory => Filename_Optional (Self.Library_Directory.Dir_Name));
   end Library_Version_Filename;

   ---------------------
   -- Limited_Imports --
   ---------------------

   function Limited_Imports
     (Self : Object; Recursive : Boolean := False) return Set.Object
   is
      Result : GPR2.Project.View.Set.Object;

      procedure Add (Self : Object);
      --  Add Self imported projects

      ---------
      -- Add --
      ---------

      procedure Add (Self : Object) is
         Position : Set.Set.Cursor;
         Inserted : Boolean;
      begin
         for Import of Definition.Get_RO (Self).Limited_Imports loop
            Result.Insert (Import, Position, Inserted);

            if Inserted and then Recursive then
               Add (Import);
            end if;
         end loop;
      end Add;

   begin
      Add (Self);
      return Result;
   end Limited_Imports;

   ----------
   -- Main --
   ----------

   function Main
     (Self       : Object;
      Executable : Simple_Name) return GPR2.Unit.Source_Unit_Identifier
   is
      Path : GPR2.Path_Name.Object;
   begin
      --  Check executable attribute
      for Attr of Self.Attributes (PRP.Builder, PRA.Executable) loop
         if Simple_Name (Attr.Value.Text) = Executable then
            return (Source => Self.Tree.Get_File
                                (Simple_Name (Attr.Index.Value)),
                    Index  => Attr.Index.At_Pos);
         end if;
      end loop;

      --  Try the Project'Main attributes
      if Self.Has_Attribute (PRA.Main) then
         for Value of Self.Attribute (PRA.Main).Values loop
            Path := Self.Executable (Simple_Name (Value.Text), Value.At_Pos);

            if Path.Simple_Name = Executable then
               return (Self.Tree.Get_File (Simple_Name (Value.Text)),
                       Value.At_Pos);
            end if;
         end loop;
      end if;

      return (GPR2.Path_Name.Undefined, 0);
   end Main;

   -----------
   -- Mains --
   -----------

   function Mains
     (Self : Object) return GPR2.Unit.Source_Unit_Vectors.Vector
   is
      Attr : constant Project.Attribute.Object := Self.Attribute (PRA.Main);
      Path : GPR2.Path_Name.Object;
   begin
      return Set : GPR2.Unit.Source_Unit_Vectors.Vector do
         if Attr.Is_Defined then
            for Main of Attr.Values loop
               Path := Self.Tree.Get_File
                 (Simple_Name (Main.Text),
                  Self);

               if Path.Is_Defined then
                  if Main.Has_At_Pos then
                     Set.Append ((Path, Main.At_Pos));
                  else
                     Set.Append ((Path, No_Index));
                  end if;
               end if;
            end loop;
         end if;
      end return;
   end Mains;

   ----------
   -- Name --
   ----------

   function Name (Self : Object) return Name_Type is
   begin
      return Definition.Get_RO (Self).Trees.Project.Name;
   end Name;

   --------------------
   -- Namespace_Root --
   --------------------

   function Namespace_Root (Self : Object) return Object is
   begin
      return Definition.Strong (Get_RO (Self).Root_View);
   end Namespace_Root;

   ----------------------
   -- Object_Directory --
   ----------------------

   function Object_Directory (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Self.Apply_Root_And_Subdirs (PRA.Object_Dir);
   end Object_Directory;

   ----------
   -- Pack --
   ----------

   function Pack
     (Self : Object;
      Name : Package_Id) return Project.Pack.Object
   is
      View   : Object := Self;
      Cursor : Project.Pack.Set.Cursor;
   begin
      loop
         Cursor := Definition.Get_RO (View).Packs.Find (Name);

         if Project.Pack.Set.Has_Element (Cursor) then
            return Project.Pack.Set.Element (Cursor);
         end if;

         exit when not View.Is_Extending;

         View := View.Extended_Root;
      end loop;

      return Project.Pack.Object'
        (Source_Reference.Pack.Object
           (Source_Reference.Pack.Create (Source_Reference.Builtin, Name)) with
         Project.Attribute.Set.Empty_Set,
         Project.Variable.Set.Empty_Set);
   end Pack;

   --------------
   -- Packages --
   --------------

   function Packages
     (Self          : Object;
      With_Defaults : Boolean := True;
      With_Config   : Boolean := True) return GPR2.Containers.Package_Id_List
   is
      Result : Containers.Package_Id_List;
   begin
      if Self.Is_Extending then
         Result := Self.Extended_Root.Packages (With_Defaults => False);
      end if;

      for Pack of Definition.Get_RO (Self).Packs loop
         Result.Include (Pack.Id);
      end loop;

      if With_Config
        and then Self.Tree.Has_Configuration
      then
         for Pack of Definition.Get_RO
           (Self.Tree.Configuration.Corresponding_View).Packs
         loop
            Result.Include (Pack.Id);
         end loop;
      end if;

      --  Check packages with default values

      if With_Defaults then
         for Pack of PRA.Get_Packages_With_Default loop
            --  Self.Has_Packages will check if the default values defined in
            --  the package apply to Self.Kind.

            if not Result.Contains (Pack)
              and then Self.Has_Package (Pack,
                                         Check_Extended => False,
                                         With_Defaults  => True,
                                         With_Config    => False)
            then
               Result.Include (Pack);
            end if;
         end loop;
      end if;

      return Result;
   end Packages;

   ---------------
   -- Path_Name --
   ---------------

   function Path_Name (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Definition.Get_RO (Self).Trees.Project.Path_Name;
   end Path_Name;

   ---------------
   -- Qualifier --
   ---------------

   function Qualifier (Self : Object) return Project_Kind is
   begin
      return Definition.Get_RO (Self).Trees.Project.Qualifier;
   end Qualifier;

   ------------------
   -- Reindex_Unit --
   ------------------

   procedure Reindex_Unit (Self : Object; From, To : Name_Type) is
      Ref : constant Definition.Ref := Definition.Get (Self);
      C   : constant Unit_Info.Set.Cursor := Ref.Units.Find (From);
   begin
      if Unit_Info.Set.Set.Has_Element (C) then
         Ref.Units.Include (To, Unit_Info.Set.Set.Element (C));
         Ref.Units.Delete (From);
      end if;

      Ref.Tree.Reindex_Unit (From, To);
   end Reindex_Unit;

   ------------------------
   -- Remove_Body_Suffix --
   ------------------------

   function Remove_Body_Suffix
     (Self : Object; Name : Simple_Name) return Value_Not_Empty
   is
      Last   : Positive := Name'First;
      Src    : GPR2.Project.Source.Object;
      Lang   : constant Language_Id :=
                 (if Self.Check_Source (Name, Src)
                  then Src.Language
                  else No_Language);
      Suffix : constant String :=
                 (if Lang /= No_Language
                  and then Self.Has_Body_Suffix (Lang)
                  then Self.Body_Suffix (Lang).Value.Text
                  else "");
   begin
      if Suffix'Length > 0
        and then Name'Length > Suffix'Length
        and then GPR2.Path_Name.To_OS_Case (Suffix) =
                   GPR2.Path_Name.To_OS_Case
                     (Strings.Fixed.Tail (String (Name), Suffix'Length))
      then
         Last := Name'Last - Suffix'Length;
      else
         while Last < Name'Last
           and then Name (Last + 1) /= '.'
         loop
            Last := Last + 1;
         end loop;
      end if;

      return Value_Not_Empty (Name (Name'First .. Last));
   end Remove_Body_Suffix;

   -------------
   -- Set_Def --
   -------------

   procedure Set_Def (Ref : out View.Object; Def : Definition_Base'Class) is
   begin
      Definition_References.Set (Ref, Def);
      pragma Assert (Ref.Get_Refcount = 1);
   end Set_Def;

   ---------------
   -- Signature --
   ---------------

   function Signature (Self : Object) return GPR2.Context.Binary_Signature is
   begin
      return Definition.Get_RO (Self).Signature;
   end Signature;

   ------------
   -- Source --
   ------------

   function Source
     (Self : Object; File : GPR2.Path_Name.Object) return Project.Source.Object
   is
      CS : constant Definition.Simple_Name_Source.Cursor :=
             Definition.Get_RO (Self).Sources_Map.Find (File.Simple_Name);
   begin
      if Definition.Simple_Name_Source.Has_Element (CS) then
         return Definition.Simple_Name_Source.Element (CS);
      else
         return  Project.Source.Undefined;
      end if;
   end Source;

   ------------
   -- Source --
   ------------

   function Source
     (Self     : Object;
      Filename : GPR2.Simple_Name) return Project.Source.Object
   is
      Result : Project.Source.Object;
   begin
      if Definition.Check_Source (Self, Filename, Result) then
         return Result;
      end if;

      raise System.Assertions.Assert_Failure with
        "Source " & String (Filename) & " not found";
   end Source;

   ------------------------
   -- Source_Directories --
   ------------------------

   function Source_Directories
     (Self : Object) return Project.Attribute.Object is
   begin
      return Self.Attribute (PRA.Source_Dirs);
   end Source_Directories;

   ------------------------
   -- Source_Directories --
   ------------------------

   function Source_Directories
     (Self : Object) return GPR2.Path_Name.Set.Object
   is
      Src_Dir_Attr : constant Project.Attribute.Object :=
                       Self.Source_Directories;
      Result : GPR2.Path_Name.Set.Object;

      procedure Append_Source_Path
        (Set : in out GPR2.Path_Name.Set.Object; Value, Directory : String);
      --  Append source path to Set. If Value is not absolute path, prefix it
      --  with Directory. If Value ends with ** output all subdirectories.

      ------------------------
      -- Append_Source_Path --
      ------------------------

      procedure Append_Source_Path
        (Set : in out GPR2.Path_Name.Set.Object; Value, Directory : String)
      is
         use Ada.Directories;
         use GNATCOLL.Utils;
         use GNAT.OS_Lib;

         Recurse   : constant Boolean := Ends_With (Value, "**");
         Base_Path : constant String :=
                       Value (Value'First
                              .. Value'Last - (if Recurse then 2 else 0));

         function With_Last_DS (Path : String) return String is
           (if Path /= "" and then Is_Directory_Separator (Path (Path'Last))
            then Path else Path & Directory_Separator);

         Path : constant String :=
                  (if Is_Absolute_Path (Base_Path) then Base_Path
                   elsif Base_Path (Base_Path'First) = '.'
                     and then
                     (Base_Path'Length = 1
                      or else (Base_Path'Length = 2
                               and then Is_Directory_Separator
                                          (Base_Path (Base_Path'Last))))
                   then Directory
                   else With_Last_DS (Directory) & Base_Path);

         procedure Search_In (Path : String);

         procedure Process (Item : Directory_Entry_Type);

         -------------
         -- Process --
         -------------

         procedure Process (Item : Directory_Entry_Type) is
         begin
            if Ada.Directories.Simple_Name (Item) not in "." | ".." then
               Search_In (Full_Name (Item));
            end if;
         end Process;

         ---------------
         -- Search_In --
         ---------------

         procedure Search_In (Path : String) is
         begin
            Set.Append
              (GPR2.Path_Name.Create_Directory (Filename_Type (Path)));

            Search
              (Path, "",
               Filter  => (Ada.Directories.Directory => True, others => False),
               Process => Process'Access);
         end Search_In;

      begin
         if Recurse then
            Search_In (Path);
         else
            Set.Append
              (GPR2.Path_Name.Create_Directory (Filename_Type (Path)));
         end if;
      end Append_Source_Path;

   begin
      if not Src_Dir_Attr.Is_Defined then
         return GPR2.Path_Name.Set.To_Set (Self.Path_Name);
      end if;

      for S of Src_Dir_Attr.Values loop
         Append_Source_Path (Result, S.Text, Self.Dir_Name.Value);
      end loop;

      return Result;
   end Source_Directories;

   -----------------
   -- Source_Path --
   -----------------

   function Source_Path
     (Self : Object; Filename : GPR2.Simple_Name) return GPR2.Path_Name.Object
   is
      CS : constant Definition.Simple_Name_Source.Cursor :=
             Definition.Get_RO (Self).Sources_Map.Find (Filename);
   begin
      if Definition.Simple_Name_Source.Has_Element (CS) then
         return Definition.Simple_Name_Source.Element (CS).Path_Name;
      else
         return GPR2.Path_Name.Undefined;
      end if;
   end Source_Path;

   function Source_Path
     (Self            : Object;
      Name            : GPR2.Simple_Name;
      Allow_Spec_File : Boolean;
      Allow_Unit_Name : Boolean) return GPR2.Path_Name.Object
   is
      CS : Definition.Simple_Name_Source.Cursor :=
             Definition.Get_RO (Self).Sources_Map.Find (Name);
   begin
      if Definition.Simple_Name_Source.Has_Element (CS) then
         return Definition.Simple_Name_Source.Element (CS).Path_Name;

      else
         if Allow_Unit_Name then
            declare
               Unit : constant Unit_Info.Object :=
                        Self.Unit (Name => Optional_Name_Type (Name));
            begin
               if Unit.Is_Defined then
                  if Unit.Has_Body then
                     return Unit.Main_Body.Source;
                  elsif Allow_Spec_File and then Unit.Has_Spec then
                     return Unit.Spec.Source;
                  end if;
               end if;
            end;
         end if;

         for Language of Self.Languages loop
            declare
               L  : constant Language_Id := +Name_Type (Language.Text);
               BS : constant Value_Type :=
                      (if Self.Has_Body_Suffix (L)
                       then Self.Body_Suffix (L).Value.Text
                       else No_Value);
            begin
               if BS /= No_Value then
                  CS := Definition.Get_RO (Self).Sources_Map.Find
                    (Name & Simple_Name (BS));

                  if Definition.Simple_Name_Source.Has_Element (CS) then
                     return Definition.Simple_Name_Source.Element
                       (CS).Path_Name;
                  end if;
               end if;

               if Allow_Spec_File then
                  declare
                     SS : constant Value_Type :=
                            (if Self.Has_Spec_Suffix (L)
                             then Self.Spec_Suffix (L).Value.Text
                             else No_Value);
                  begin
                     if SS /= No_Value then
                        CS := Definition.Get_RO (Self).Sources_Map.Find
                          (Name & Simple_Name (SS));

                        if Definition.Simple_Name_Source.Has_Element (CS) then
                           return Definition.Simple_Name_Source.Element
                             (CS).Path_Name;
                        end if;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end if;

      return GPR2.Path_Name.Undefined;
   end Source_Path;

   -------------------------
   -- Source_Subdirectory --
   -------------------------

   function Source_Subdirectory (Self : Object) return GPR2.Path_Name.Object is
   begin
      return Self.Object_Directory.Compose
        (Self.Tree.Src_Subdirs, Directory => True);
   end Source_Subdirectory;

   -------------
   -- Sources --
   -------------

   function Sources
     (Self   : Object;
      Filter : Source_Kind := K_All) return Project.Source.Set.Object
   is
      use type Ada.Streams.Stream_Element_Array;
      Data : constant Project.Definition.Ref := Project.Definition.Get (Self);
   begin
      if not Definition.Are_Sources_Loaded (Data.Tree.all) then
         Data.Tree.Update_Sources (With_Runtime => Self.Is_Runtime);

      elsif Data.Sources_Signature = GPR2.Context.Default_Signature then
         Data.Update_Sources
           (Self, Stop_On_Error => True, Backends => Source_Info.All_Backends);
      end if;

      --  Compute and return the sources depending on the filtering

      if Filter = K_All then
         return Data.Sources;

      else
         return S_Set : Project.Source.Set.Object do
            for S of Data.Sources loop
               declare
                  Is_Interface : constant Boolean :=
                                   S.Has_Units
                                   and then S.Has_Single_Unit
                                   and then Data.Units.Contains (S.Unit_Name)
                                   and then S.Is_Interface;
                  --  All sources related to an interface unit are also
                  --  taken as interface (not only the spec)???

               begin
                  if (Filter = K_Interface_Only and then Is_Interface)
                    or else
                      (Filter = K_Not_Interface and then not Is_Interface)
                  then
                     S_Set.Insert (S);
                  end if;
               end;
            end loop;
         end return;
      end if;
   end Sources;

   ------------
   -- Strong --
   ------------

   function Strong (Weak : Weak_Reference) return Object is
      Result : Object;
   begin
      Definition_References.Set (Result, Weak);
      return Result;
   end Strong;

   ----------
   -- Tree --
   ----------

   function Tree (Self : Object) return not null access Project.Tree.Object is
   begin
      return Definition.Get_RO (Self).Tree;
   end Tree;

   ---------
   -- Typ --
   ---------

   function Typ (Self : Object; Name : Name_Type) return Project.Typ.Object is
   begin
      return Definition.Get_RO (Self).Types (Name);
   end Typ;

   -----------
   -- Types --
   -----------

   function Types (Self : Object) return Project.Typ.Set.Object is
   begin
      return Definition.Get_RO (Self).Types;
   end Types;

   -----------
   -- Units --
   -----------

   function Unit (Self : Object; Name : Name_Type) return Unit_Info.Object is
      CU : constant Unit_Info.Set.Cursor :=
             Definition.Get_RO (Self).Units.Find (Name);
   begin
      if Unit_Info.Set.Set.Has_Element (CU) then
         return Unit_Info.Set.Set.Element (CU);
      else
         return Unit_Info.Undefined;
      end if;
   end Unit;

   -----------
   -- Units --
   -----------

   function Units (Self : Object) return Unit_Info.Set.Object is
   begin
      return Definition.Get_RO (Self).Units;
   end Units;

   --------------
   -- Variable --
   --------------

   function Variable
     (Self : Object; Name : Name_Type) return Project.Variable.Object is
   begin
      return Definition.Get_RO (Self).Vars (Name);
   end Variable;

   function Variable (Self : Object;
                      Pack : Package_Id;
                      Name : Name_Type) return Project.Variable.Object is
   begin
      return Self.Pack (Pack).Vars.Element (Name);
   end Variable;

   ---------------
   -- Variables --
   ---------------

   function Variables (Self : Object) return Project.Variable.Set.Object is
   begin
      return Definition.Get_RO (Self).Vars;
   end Variables;

   function Variables
     (Self : Object; Pack : Package_Id) return Project.Variable.Set.Object is
   begin
      return Self.Pack (Pack).Vars;
   end Variables;

   --------------
   -- View_For --
   --------------

   function View_For (Self : Object; Name : Name_Type) return View.Object is
      Data : constant Definition.Const_Ref := Definition.Get_RO (Self);
      Dad  : Object := Data.Extended_Root;
   begin
      --  Lookup in the ancestors first

      while Dad.Is_Defined loop
         if Dad.Name = Name then
            return Dad;
         end if;

         Dad := Definition.Get_RO (Dad).Extended_Root;
      end loop;

      --  Lookup in the imported next

      declare
         package DPV renames Definition.Project_View_Store;
         Position : constant DPV.Cursor := Data.Imports.Find (Name);
      begin
         if DPV.Has_Element (Position) then
            return DPV.Element (Position);
         end if;
      end;

      --  Try configuration project

      declare
         CV : constant Project.View.Object :=
                (if Data.Tree.Has_Configuration
                 then Data.Tree.Configuration.Corresponding_View
                 else Project.View.Undefined);
      begin
         --  If not found let's check if it is the configuration or runtime
         --  project. Note that this means that any Runtime or Config user's
         --  project name will have precedence.

         if CV.Is_Defined and then CV.Name = Name then
            return CV;

         --  Try runtime project

         elsif Data.Tree.Has_Runtime_Project
           and then Data.Tree.Runtime_Project.Name = Name
         then
            return Data.Tree.Runtime_Project;
         end if;
      end;

      return Undefined;
   end View_For;

begin
   Definition.Get_RO                 := Get_RO'Access;
   Definition.Get_RW                 := Get_RW'Access;
   Definition.Get                    := Get_Ref'Access;
   Definition.Set                    := Set_Def'Access;
   Definition.Refcount               := Refcount'Access;
   Definition.Weak                   := Weak'Access;
   Definition.Strong                 := Strong'Access;
end GPR2.Project.View;
