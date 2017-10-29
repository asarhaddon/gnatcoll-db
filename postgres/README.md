The GNAT Components Collection (GNATCOLL) - Postgres
====================================================

This component extends the GNATCOLL.SQL hierarchy for the PostgreSQL DBMS.

Dependencies
------------

This component requires the following external components, that should be
available on your system:

- gprbuild
- gnatcoll-core
- postgres

Configuring the build process
-----------------------------

The following variables can be used to configure the build process:

General:

   prefix     : location of the installation, the default is the running
                GNAT installation root.

   BUILD      : control the build options : PROD (default) or DEBUG

   PROCESSORS : parallel compilation (default is 0, which uses all available
                cores)

   TARGET     : for cross-compilation, auto-detected for native platforms

   SOURCE_DIR : for out-of-tree build

Component-specific:

   GNATCOLL_HASPQPREPARE : Whether PQPREPARE is available (yes/no)

To use the default options:

   $ make setup

Building
--------

The component is built using a standalone GPR project file.

However, to build all versions of the library (static, relocatable and
static-pic) it is simpler to use the provided Makefile:

$ make

Then, to install it:

$ make install


Bug reports
-----------

Please send questions and bug reports to report@adacore.com following
the same procedures used to submit reports with the GNAT toolset itself.