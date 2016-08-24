pimatic mobile-frontend plugin
======================

Provides a [jQuery mobile](http://jquerymobile.com/) page, witch let you control
your actuators, display sensor values and let you add and edit rules. 

Example configuration
---------------------

    {
      "plugin": "mobile-frontend",
      "customTitle": "Pimatic", 
      "theme": "water",
      "flat": true,
      "debug": false,
      "mode": "production"
    }
    
Mobile frontend development
---------------------------

For performance reasons the `"production"` mode uses minified and pre-compiled code. If you need to debug the mobile frontend code, e.g., as you are developing an mobile frontend extension, set the mode as part of the plugin configuration to `"development"`. Then clear all browser caches and delete all app settings. Best is to use an incognito tab for testing.  
