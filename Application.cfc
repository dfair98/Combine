component {
// ------------------------ APPLICATION SETTINGS ------------------------ //
    this.name = "combine1";
    this.applicationTimeout = CreateTimeSpan(10, 0, 0, 0); //10 days
    this.applicationroot = getDirectoryFromPath(getCurrentTemplatePath());

// ------------------------ APP MAPPINGS ------------------------ //
    this.mappings["/libs"] = this.applicationroot & "libs/";

// ------------------------ JAVA SETTINGS ------------------------ //
    this.javaSettings = { 
        LoadPaths = ["/libs"],
        reloadOnChange="true"
    };

// ------------------------ CF SETTINGS ------------------------ //
    setting enablecfoutputonly="true" requesttimeout="5" showdebugoutput="no";


// ------------------------ APPLICATION EVENT HANDLERS  ------------------------ //

    /**
    * I am executed when the application first starts
    * @access public
    * @returntype any
    * @output false
    **/
    function onApplicationStart() {
        return true;
    }


   


}   