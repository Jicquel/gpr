------------------------------------------------------------------------------
--                                                                          --
--                           GPR2 PROJECT MANAGER                           --
--                                                                          --
--         Copyright (C) 2016-2018, Free Software Foundation, Inc.          --
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

with GNAT.OS_Lib;

package body GPR2.Project is

   use Ada;

   ------------
   -- Create --
   ------------

   function Create
     (Name  : Name_Type;
      Paths : Path_Name.Set.Object := Path_Name.Set.Set.Empty_List)
      return GPR2.Path_Name.Object
   is
      use GNAT;

      DS       : constant Character := OS_Lib.Directory_Separator;

      GPR_Name : constant Name_Type :=
                   (if Directories.Extension (String (Name)) in "gpr" | "cgpr"
                    then Name
                    else Name & ".gpr");

   begin
      --  If the file exists or an absolute path has been specificed or there
      --  is no ADA_PROJECT_PATH, just create the Path_Name_Type using the
      --  given Name.

      if OS_Lib.Is_Absolute_Path (String (GPR_Name)) then
         return Path_Name.Create
           (GPR_Name,
            Name_Type (OS_Lib.Normalize_Pathname (String (GPR_Name))));

      else
         --  If we have an empty Paths set, this is the root project and it is
         --  expected to look into the current working directorty in this case.

         if Paths.Is_Empty then
            if Directories.Exists
                (Directories.Current_Directory & DS & String (Name))
            then
               return Path_Name.Create
                 (GPR_Name,
                  Name_Type (OS_Lib.Normalize_Pathname
                    (Directories.Current_Directory & DS & String (Name))));
            end if;

         else
            for P of Paths loop
               declare
                  F_Name : constant String :=
                             String (Path_Name.Dir_Name (P))
                             & String (GPR_Name);
               begin
                  if Directories.Exists (F_Name) then
                     return Path_Name.Create
                       (GPR_Name,
                        Name_Type (OS_Lib.Normalize_Pathname (F_Name)));
                  end if;
               end;
            end loop;
         end if;
      end if;

      return Path_Name.Create (GPR_Name, GPR_Name);
   end Create;

   ------------------
   -- Search_Paths --
   ------------------

   function Search_Paths
     (Root_Project      : Path_Name.Object;
      Tree_Search_Paths : Path_Name.Set.Object) return Path_Name.Set.Object is
   begin
      return Result : Path_Name.Set.Object := Tree_Search_Paths do
         Result.Prepend
           (Path_Name.Create_Directory (Name_Type (Root_Project.Dir_Name)));
      end return;
   end Search_Paths;

end GPR2.Project;
