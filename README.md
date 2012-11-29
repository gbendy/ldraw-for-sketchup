LDraw-for-SketchUp
==================

LDraw Tools for SketchUp

29 Nov 2012

 * Look on disk for part before creating a new ComponentDefinition from file. 

  The .ldr importer works like this:
   * Look in-model for the part name.
   * Look on disk for part_no.skp, load if found.
   * Lastly, if the previous 2 searches fail, create a new ComponentDefinition.

28 Nov 2012

 * Added a basic .ldr exporter.
  * Exports entire model. 
  * Exports only top-level Component Instances. 
  * In order to be compatible with LDraw tools, the Instance Definition names need to match LDraw part number without the
   .dat extension. i.e. 3001

26 Nov 2012 - Updates

* Plugin appears in the `Plugins/LDraw menu`.
* Import `.ldr` files.
* Import parts by LDraw Number.

Parts/models are imported to the Component Browser, not directly in the model.

Currently requires LDraw to be installed to `C:\Program Files (x86)\LDraw`

----

