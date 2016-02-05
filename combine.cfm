<cfscript>
/*
	Create the combine object, or use the cached version

	@enableCache:				true: cache combined/compressed files locally, false: re-combine on each request
	@cachePath:					where should the cached combined files be stored?
	@enableETags:				should we return etags in the headers? Etags allow the browser to do conditional requests, i.e. only give me the file if the etag is different.
	@enableJSMin:				compress Javascript using JSMin?
	@enableYuiCSS:				compress CSS using YUI CSS compressor
	@skipMissingFiles:			true: ignore file-not-found errors, false: throw errors when a requested file cannot be found
	@getFileModifiedMethod:		'java' or 'com'. Which method to use to obtain the last modified dates of local files. Java is the recommended and default option
*/
	variables.sKey = 'combine_#hash(getCurrentTemplatePath())#';
	
	if(isStruct('application') && structKeyExists(application, variables.sKey) && !structKeyExists(url, 'reinit')){
		// use a cached version of Combine if available (unless reinit is specified in the url)
		variables.oCombine = application[variables.sKey];
	}else{
		// Load the combine object
		variables.oCombine = createObject("component", "Combine").init(
			enableCache: true,
			cachePath: expandPath('example/cache'),
			enableETags: true,
			enableJSMin: true,
			enableYuiCSS: true,
			skipMissingFiles: false
		);

		// cache the object in the application scope, if we have an application scope!
		if(isStruct('application')) application[variables.sKey] = variables.oCombine;
	}

	/*	Make sure we have the required paths (files to combine) in the url */
	if(!structKeyExists(url, 'files')){
		return;
	} 

	/*	Combine the files, and handle any errors in an appropriate way for the current app */
	try{
		variables.oCombine.combine(files: url.files);
	}catch(any e){
		writedump(e);
		abort;
		handleError(e);
	}


	    /**
    * I am responsible for handling errors
    * @access public
    * @returntype void
    * @output false
    **/
    function handleError(required any cfcatch){
        writedump(var:arguments.cfcatch);
        writelog(text:'Fault caught by "combine"',file:'combine');
        abort;
    }
</cfscript>
