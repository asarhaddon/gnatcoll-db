------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2011-2012, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

--  This package provides support for parsing the .ali and .gli files that
--  are generated by GNAT and gcc. In particular, those files contain
--  information that can be used to do cross-references for entities (going
--  from references to their declaration for instance).
--
--  A typical example would be:
--
--  declare
--     Session : Session_Type;
--  begin
--     GNATCOLL.SQL.Sessions.Setup
--        (Descr   => GNATCOLL.SQL.Sqlite.Setup (":memory:"));
--     Session := Get_New_Session;
--
--     ... parse the project through GNATCOLL.Projects
--
--     Create_Database (Session.DB);
--     Parse_All_LI_Files (Session, ...);
--   end;

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with GNATCOLL.Projects;     use GNATCOLL.Projects;
with GNATCOLL.SQL.Exec;     use GNATCOLL.SQL.Exec;
with GNATCOLL.VFS;

package GNATCOLL.Xref is

   ---------------------------------
   --  Creating the xref database --
   ---------------------------------

   type Xref_Database is tagged private;

   procedure Setup_DB
     (Self : in out Xref_Database;
      DB   : not null access
        GNATCOLL.SQL.Exec.Database_Description_Record'Class);
   --  Points to the actual database that will be used to store the xref
   --  information.
   --  This database might contain the information from several projects.
   --  An example:
   --     declare
   --        Xref : Xref_Database;
   --     begin
   --        Xref.Setup_DB
   --          (GNATCOLL.SQL.Sqlite.Setup (":memory:"));
   --     end;

   procedure Free (Self : in out Xref_Database);
   --  Free the memory allocated for Self, and closes the database connection.

   procedure Parse_All_LI_Files
     (Self                : in out Xref_Database;
      Tree                : Project_Tree;
      Project             : Project_Type;
      Parse_Runtime_Files : Boolean := True;
      From_DB_Name        : String := "";
      To_DB_Name          : String := "");
   --  Parse all the LI files for the project, and stores the xref info in the
   --  DB database.
   --
   --  The database in DB is first initialized by copying the database
   --  from From_DB_Name (if one exists).
   --  When no using sqlite, this procedure cannot initialize a database from
   --  another one. In this case, the database must always have been created
   --  first (through a call to Create_Database).
   --
   --  On exit, the in-memory database is copied back to To_DB_Name if that
   --  file is writable and the parameter is not the empty string.
   --  As such, it is possible to generate an entities database as part of a
   --  nightly build of an application, in a read-only area. Then each user's
   --  database is initially copied from that nightly database, and then can
   --  either be kept in memory (passing "" for To_DB_Name) or dumped back to
   --  a local user-writable file.
   --
   --  In fact, depending on the number of LI files to update, GNATCOLL might
   --  decide to temporarily work in memory. Thus, we have the following
   --  databases involved:
   --      From_DB_Name (e.g. from nightly builds)
   --          |        (copy only if DB doesn't exist yet
   --          v           and is not the same file already)
   --         DB
   --          |
   --          v
   --       :memory:    (if the number of LI files to update is big)
   --          |
   --          v
   --         DB        (overridden after the update in memory, or changed
   --          |         directly)
   --          v
   --      To_DB_Name   (if specified and different from DB)
   --
   --  If DB is an in-memory database, this procedure will be faster
   --  than directly modifying the database on the disk (through a call to
   --  Parse_All_LI_Files) when lots of changes need to be made.
   --  Otherwise, it will be slower since dumping the in-memory database to the
   --  disk is likely to take several seconds.
   --
   --  Parse_Runtime_Files indicates whether we should be looking at the
   --  predefined object directories to find extra ALI files to parse. This
   --  will in general include the Ada runtime.

   -------------
   -- Queries --
   -------------

   type Entity_Information is private;
   No_Entity : constant Entity_Information;
   --  The description of an entity.
   --  This entity is independent from the database (ie it remains usable even
   --  if the database has changed since you retrieved the Entity_Information).
   --  However, it might not be pointing to an entity that no longer exists.
   --  This information, however, is only valid as long as the object
   --  Xref_Database hasn't been destroyed.

   function Get_Entity
     (Self   : Xref_Database;
      Name   : String;
      File   : String;
      Line   : Integer := -1;
      Column : Integer := -1) return Entity_Information;
   function Get_Entity
     (Self   : Xref_Database;
      Name   : String;
      File   : GNATCOLL.VFS.Virtual_File;
      Line   : Integer := -1;
      Column : Integer := -1) return Entity_Information;
   --  Return the entity that has a reference at the given location.
   --  When the file is passed as a string, it is permissible to pass only the
   --  basename (or a string like "partial/path/basename") that will be matched
   --  against all known files in the database.

   type Entity_Reference is record
      File   : GNATCOLL.VFS.Virtual_File;
      Line   : Integer;
      Column : Integer;
      Kind   : Ada.Strings.Unbounded.Unbounded_String;
      Scope  : Entity_Information;
   end record;
   No_Entity_Reference : constant Entity_Reference;
   --  A reference to an entity, at a given location.

   type Entity_Declaration is record
      Name     : Ada.Strings.Unbounded.Unbounded_String;
      Location : Entity_Reference;
   end record;
   No_Entity_Declaration : constant Entity_Declaration;

   function Declaration
     (Xref   : Xref_Database'Class;
      Entity : Entity_Information) return Entity_Declaration;
   --  Return the name of the entity

   type Base_Cursor is abstract tagged private;
   function Has_Element (Self : Base_Cursor) return Boolean;
   procedure Next (Self : in out Base_Cursor);

   type References_Cursor is new Base_Cursor with private;
   function Element (Self : References_Cursor) return Entity_Reference;
   function References
     (Self   : Xref_Database'Class;
      Entity : Entity_Information) return References_Cursor;

   type Entities_Cursor is new Base_Cursor with private;
   function Element (Self : Entities_Cursor) return Entity_Information;

   type Parameter_Kind is
     (In_Parameter,
      Out_Parameter,
      In_Out_Parameter,
      Access_Parameter);
   type Parameter_Information is record
      Parameter : Entity_Information;
      Kind      : Parameter_Kind;
   end record;

   type Parameters_Cursor is new Base_Cursor with private;
   function Element (Self : Parameters_Cursor) return Parameter_Information;
   function Parameters
     (Self   : Xref_Database'Class;
      Entity : Entity_Information) return Parameters_Cursor;
   --  Return the list of parameters for the given subprogram. They are in the
   --  same order as in the source.

private
   type Xref_Database is tagged record
      DB      : GNATCOLL.SQL.Exec.Database_Connection;

      DB_Created : Boolean := False;
      --  Whether we have already created the database (or assumed that it
      --  existed). This is so that running Parse_All_LI_Files multiple times
      --  for an in-memory database does not always try to recreate it
   end record;

   type Entity_Information is record
      Id          : Integer;
   end record;
   No_Entity : constant Entity_Information :=
     (Id => -1);

   No_Entity_Reference : constant Entity_Reference :=
     (File   => GNATCOLL.VFS.No_File,
      Line   => -1,
      Column => -1,
      Kind   => Ada.Strings.Unbounded.Null_Unbounded_String,
      Scope  => No_Entity);

   No_Entity_Declaration : constant Entity_Declaration :=
     (Name     => Ada.Strings.Unbounded.Null_Unbounded_String,
      Location => No_Entity_Reference);

   type Base_Cursor is abstract tagged record
      DBCursor : GNATCOLL.SQL.Exec.Forward_Cursor;
   end record;

   type References_Cursor is new Base_Cursor with null record;
   type Entities_Cursor is new Base_Cursor with null record;
   type Parameters_Cursor is new Base_Cursor with null record;

end GNATCOLL.Xref;
