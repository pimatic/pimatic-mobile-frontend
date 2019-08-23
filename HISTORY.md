# Release History

* 20190823, V0.9.16
    * Disabled automatic capitalization and correction for 
      "Username" input of the Login dialog
    * Added display of active button (last button pressed) 
      for ButtonsDevice (feature can be turned off)
    * Fixed minimum height for presence devices, PR #28, thanks @atus
    
* 20190415, V0.9.15
    * Added format and units options for uptime displayFormat
    * Added support for formatting of user defined enum value labels 
    * Added support for rendering the labels of Shutter device buttons 
      with xUpLabel und xDownLabel values
    * Fixed wrong width with modern browser on first load, issue 
      pimatic/#1119, thanks @akicker 
      
* 20190325, V0.9.14
    * Added unit Bps and bps as si-prefixes with human-format
    * Added support for formatting Euro currency values
    * Added xAttributeOption displayFormat filter for attribute 
      values including formatters for uptime, fixed, and localeString