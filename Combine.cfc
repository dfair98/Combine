/**
* provides javascript and css file merge and compress functionality, to reduce the overhead caused by file sizes and multiple requests
* @file  Combine.cfc
* @author Joe Roberts
* @contributor  David Fairfield (david.fairfield@gmail.com)
* @displayname Combine
* @output false
* 
* */
component {
	// ------------------------ CONSTRUCTOR ------------------------ //

	/**
	* I am responsible for instantiating combine component
	* @access public
	* @returntype Combine
	* @enableCache.hint When enabled, the content we generate by combining multiple files is stored locally, so we don't have to regenerate on each request.
	* @cachePath.hint Where to store the local cache of combined files
	* @enableETags.hint Etags are a 'hash' which represents what is in the response. These allow the browser to perform conditional requests, i.e. only give me the content if your Etag is different to my Etag.
	* @enableJSMin.hint compress JS using JSMin?
	* @enableYuiCSS.hint compress CSS using the YUI css compressor?
	* @outputSperator.hint seperates the output of different file content
	* @skipMissingFiles.hint skip files that don't exists? If false, non-existent files will cause an error
	* @getFileModifiedMethod.hint java or com. Which technique to use to get the last modified times for files.
	* @enable304s.hint 304 (not-modified) is returned when the request's etag matches the current response, so we return a 304 instead of the content, instructing the browser to use it's cache. A valid reason for disabling this would be if you have an effective caching layer on your web server, which handles 304s more efficiently. However, unlike Combine the caching layer will not check the modified state of each individual css/js file. Note that to enable 304s, you must also enable eTags.
	* @cacheControl.hint specify an optional cache-control header, to define caching rules for browsers & proxies. Recommended! See http://palisade.plynt.com/issues/2008Jul/cache-control-attributes/ & http://www.w3.org/Protocols/rfc2616/rfc2616-sec14.html.
	**/
		function init(
			required boolean enableCache,
			required string cachePath,
			required boolean enableETags,
			required boolean enableJSMin,
			required boolean enableYuiCSS,
					 string outputSeperator="#chr(13)#",
					 boolean skipMissingFiles="true",
					 string getFileModifiedMethod="java",
					 boolean enable304s="true",
					 string cacheControl="max-age=3600"


		){
			variables.sCachePath = arguments.cachePath;
			// enable caching
			variables.bCache = arguments.enableCache;
			// enable etags - browsers use this hash to decide if their cached version is up to date
			variables.bEtags = arguments.enableETags;
			// enable jsmin compression of javascript
			variables.bJsMin = arguments.enableJSMin;
			// enable yui css compression
			variables.bYuiCss = arguments.enableYuiCSS;
			// text used to delimit the merged files in the final output
			variables.sOutputDelimiter = arguments.outputSeperator;
			// skip files that don't exists? If false, non-existent files will cause an error
			variables.bSkipMissingFiles = arguments.skipMissingFiles;
			
			// configure the content-types that are returned
			variables.stContentTypes = {
				css = 'text/css',
				js = 'application/javascript'
			};
			
			
			// cache-control header
			variables.sCacheControl = arguments.cacheControl;
			// return 304s when conditional requests are made with matching Etags?
			variables.bEnable304s = arguments.enable304s;
			
					
			variables.jOutputStream = createObject("java","java.io.ByteArrayOutputStream");
			variables.jStringReader = createObject("java","java.io.StringReader");
			
			// If using jsMin, we need to load the required Java objects
			if(variables.bJsMin) variables.jJSMin = createObject("java","com.magnoliabox.jsmin.JSMin");
	
			// If using the YUI CSS Compressor, we need to load the required Java objects
			if(variables.bYuiCss){
				variables.jStringWriter = createObject("java","java.io.StringWriter");
				variables.jYuiCssCompressor = createObject("java","com.yahoo.platform.yui.compressor.CssCompressor");
			}
			
			// determine which method to use for getting the file last modified dates
			if(arguments.getFileModifiedMethod eq 'com'){
				variables.fso = CreateObject("COM", "Scripting.FileSystemObject");
				// calls to getFileDateLastModified() are handled by getFileDateLastModified_com()
				variables.getFileDateLastModified = variables.getFileDateLastModified_com;
			}else{
				variables.jFile = CreateObject("java", "java.io.File");
				// calls to getFileDateLastModified() are handled by getFileDateLastModified_java()
				variables.getFileDateLastModified = variables.getFileDateLastModified_java;
			}
			
			// ensure the cache directory exists 
			if(!directoryExists(variables.sCachePath)) directoryCreate(variables.sCachePath);
			
			return this;

		}


		/**
		* I am responsible for combining a list js or css files into a single file, which is output, and cached if caching is enabled
		* @access public
		* @returntype void
		* @files.hint a delimited list of jss or css paths to combine.
		* @type.hint js,css.
		* @delimiter.hint the delimiter used in the provided paths string.
		**/
			function combine(
				required string files,
				string type="",
				string delimiter=","
			){
				var sType = '';
				var lastModified = 0;
				var sFilePath = '';
				var sCorrectedFilePaths = '';
				var i = 0;
				var sDelimiter = arguments.delimiter;
				
				var etag = '';
				var sCacheFile = '';
				var sOutput = '';
				var sFileContent = '';
				
				var sHttpNoneMatch = '';
				
				var filePaths = convertToAbsolutePaths(files, delimiter);
				
				// determine what file type we are dealing with
				sType = listLast( listFirst(filePaths, sDelimiter) , '.');
				
				
				// security check 
				if(!listfindnocase('js,css',sType)){
					cfheader(statuscode="400",  statustext="Bad Request");
					return;
				}
				
				// get the latest last modified date 
				sCorrectedFilePaths = '';
				for(var sFilePath in filePaths){
					 // check it is a valid JS or CSS file. Don't allow mixed content (all JS or all CSS only) 
					if(fileExists( sFilePath ) && listLast(sFilePath, '.') is sType){
						lastModified = max(lastModified, getFileDateLastModified( sFilePath ));
						sCorrectedFilePaths = listAppend(sCorrectedFilePaths, sFilePath, sDelimiter);
					}else if(!variables.bSkipMissingFiles){	
						throw(type="combine.missingFileException", message="A file specified in the combine (#sType#) path doesn't exist.", detail="file: #sFilePath#", extendedinfo="full combine path list: #filePaths#");
					}

				}
				
				filePaths = sCorrectedFilePaths;
				
				// create a string to be used as an Etag - in the response header 
				etag = lastModified & '-' & hash(filePaths);
				
				
				// output the etag, this allows the browser to make conditional requests
				// (i.e. browser says to server: only return me the file if your eTag is different to mine)
				
				if(variables.bEtags){
					 cfheader(name="ETag", value="""#etag#""");
				}
					
				
				
				// obtain the HTTP_IF_NONE_MATCH request header - strange behavior using structKeyExists() on Railo 3.1 
				try{
					sHttpNoneMatch = cgi.HTTP_IF_NONE_MATCH;
				}catch(any e){
					writedump(e);
				}
					
				
				
				 
				// if the browser is doing a conditional request, then only send it the file if the browser's
				// etag doesn't match the server's etag (i.e. the browser's file is different to the server's)
				
				if(sHttpNoneMatch contains eTag && variables.bEtags && variables.bEnable304s){
					//  nothing has changed, return nothing 
					// getPageContext().getFusionContext().getResponse().setHeader('Content-Type','#variables.stContentTypes[sType]#');
					cfheader(name="Content-Type", value="#variables.stContentTypes[sType]#");
					cfheader(statuscode="304", statustext="Not Modified");
					
					//specific Cache-Control header? 
					if(len(variables.sCacheControl)){
						 cfheader(name="Cache-Control",value="#variables.sCacheControl#");
					}
				
					return;
				}else{
					// first time visit, or files have changed 
					
					if(variables.bCache){
						
						// try to return a cached version of the file 		
						sCacheFile = variables.sCachePath & '/' & etag & '.' & sType;
						if(fileExists(sCacheFile)){
							sOutput = fileRead(sCacheFile);
							
							// output contents --->
							outputContent(sOutput, sType, variables.sCacheControl);	
							return;
						}
						
					}
					
					// combine the file contents into 1 string 
					sOutput = '';
					for(var file in filePaths){
						sFileContent = fileRead(file);
						
						sOutput = sOutput & variables.sOutputDelimiter & sFileContent;
					}
					
					
					// 'Minify' the javascript with jsmin
					if(variables.bJsMin and sType eq 'js'){
						sOutput = compressJsWithJSMin(sOutput);
					}else if(variables.bYuiCss and sType eq 'css'){
						sOutput = compressCssWithYUI(sOutput);
					}
					
					//output contents
					outputContent(sOutput, sType, variables.sCacheControl);
					
					
					// write the cache file 
					if(variables.bCache){
						fileWrite(sCacheFile,soutput);
						
					}
					
				}
			}


		/**
		* I am responsible for outputting content
		* @access public
		* @returntype void
		* @output true
		**/
			function outputContent(
				required string sOut,
				required string sType,
				string sCacheControl=''
			){
				// content-type (e.g. text/css) 
				cfheader(name="Content-Type", value="#variables.stContentTypes[sType]#");

				// specific Cache-Control header? 
				if(len(arguments.sCacheControl)){
					 cfheader(name="Cache-Control", value="#arguments.sCacheControl#");
				}
				
				writeoutput(arguments.sOut);
			}
		/**
		* I am responsible for getting file date last modified using 'Scripting.FileSystemObject' com object 
		* @access private
		* @returntype string
		* @output false
		**/
			function getFileDateLastModified_com(required string path){
				var file = variables.fso.GetFile(arguments.path);
				return file.DateLastModified;
			}

		/**
		* I am responsible for for getting file date last modified using 'java.io.file'. Recommended
		* @access private
		* @returntype string
		* @output false
		**/
			function getFileDateLastModified_java(required string path){
				var file = variables.jFile.init(arguments.path);
				return file.lastModified();
			}

	
		/**
		* I am responsible for taking a javascript string and returns a compressed version, using JSMin
		* @access private
		* @returntype string
		* @output false
		**/
			function compressJsWithJSMin(required string sInput){

				var sOut = arguments.sInput;
					
				var joOutput = variables.jOutputStream.init();
				var joInput = variables.jStringReader.init(sOut);
				var joJSMin = variables.jJSMin.init(joInput, joOutput);
				
				joJSMin.jsmin();
				joInput.close();
				sOut = joOutput.toString();
				joOutput.close();
				
				return sOut;
			}
	
		/**
		* I am responsible for taking a css string and returns a compressed version, using the YUI css compressor
		* @access private
		* @returntype string
		* @output false
		**/
			function compressCssWithYUI(required string sInput){

				var sOut = arguments.sInput;
					
				var joInput = variables.jStringReader.init(sOut);
				var joOutput = variables.jStringWriter.init();
				var joYUI = variables.jYuiCssCompressor.init(joInput);
				
				joYUI.compress(joOutput, javaCast('int',-1));
				joInput.close();
				sOut = joOutput.toString();
				joOutput.close();
				
				return sOut;

			}
	
		/**
		* I am responsible for taking a list of relative paths and makes them absolute, using expandPath
		* @access private
		* @returntype string
		* @output false
		**/
			function convertToAbsolutePaths(required string relativePaths, string delimiter=','){
				var filePaths = '';
				var path = '';
				for(path in arguments.relativepaths){
					filePaths = listAppend(filePaths, expandPath(path), arguments.delimiter);
				}

				return filePaths;
			}


}

