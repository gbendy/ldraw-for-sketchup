LDraw-for-SketchUp
==================

LDraw Tools for SketchUp

29 Apr 2013

 * Moved importer options to JF::LDraw::@opts.
 * Added a JF::LDraw::Color class to store LDConfig data rather than using a hash.
 * Pass JF::LDraw::@opts into color processor plugins.
 * Refactored color plugins to a dedicated plugin file and changed signature and name of base color plugin class.

26 Apr 2013

 * Generalize material support in Colors, add support for MATTE_METALLIC finish.

25 Apr 2013

 * Add VALIDATE_TRANSFORM config option to check part transforms are not degenerate.
 * Add MAKE_COMPONENT config option to import LDR as a component.
 * Add PHYSICAL_SCALE config option to scale the component to real world lego size.
 * Add color import plugin system to allow users to modify colors as they are imported. See color.rb for details.

30 Nov 2012

 * Added colors ro imports.
 * Import All Materials menu.
 * Patterns & Stickers to Imports.
 * Save Component context menu.

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

