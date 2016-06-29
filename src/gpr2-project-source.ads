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

with GPR2.Source;

with GPR2.Project.View;

package GPR2.Project.Source is

   type Object is tagged private;

   function "<" (Left, Right : Object) return Boolean;

   function Create
     (Source : GPR2.Source.Object;
      View   : Project.View.Object) return Object;
   --  Constructor for Object

   function View (Self : Object) return Project.View.Object;
   --  The view the source is in

   function Source (Self : Object) return GPR2.Source.Object;
   --  The source object

private

   type Object is tagged record
      Source : GPR2.Source.Object;
      View   : Project.View.Object;
   end record;

end GPR2.Project.Source;
