/-  blog
::  Fixture for the Hoon importer; not supplied by the design doc.
|%
+$  sample  [title=title:blog values=(list @ud)]
+$  recursive  chain:blog
+$  nested  [id=@ud value=$^(@ud [a=@ud b=@t])]
--
