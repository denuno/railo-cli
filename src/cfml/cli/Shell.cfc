component {

	System = createObject("java", "java.lang.System");
	ANSIBuffer = createObject("java", "jline.ANSIBuffer");
    StringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
	keepRunning = true;
    reloadshell = false;
	script = "";
	initialDirectory = createObject("java","java.lang.System").getProperty("user.dir");
	pwd = initialDirectory;

	function init(inStream, printWriter) {
		if(isNull(printWriter)) {
			if(findNoCase("windows",server.os.name)) {
				variables.ansiOut = createObject("java","org.fusesource.jansi.AnsiConsole").out;
        		var printWriter = createObject("java","java.io.PrintWriter").init(
        			createObject("java","java.io.OutputStreamWriter").init(variables.ansiOut,
        			// default to Cp850 encoding for Windows
        			System.getProperty("jline.WindowsTerminal.output.encoding", "Cp850"))
        			);
				var FileDescriptor = createObject("java","java.io.FileDescriptor").init();
		    	inStream = createObject("java","java.io.FileInputStream").init(FileDescriptor.in);
				reader = createObject("java","jline.ConsoleReader").init(inStream,printWriter);
			} else {
				//new PrintWriter(OutputStreamWriter(System.out,System.getProperty("jline.WindowsTerminal.output.encoding",System.getProperty("file.encoding"))));
		    	reader = createObject("java","jline.ConsoleReader").init();
			}
		} else {
			if(isNull(arguments.inStream)) {
		    	var FileDescriptor = createObject("java","java.io.FileDescriptor").init();
		    	inStream = createObject("java","java.io.FileInputStream").init(FileDescriptor.in);
			}
	    	reader = createObject("java","jline.ConsoleReader").init(inStream,printWriter);
		}
    	return this;
	}

	function getReader() {
    	return reader;
	}

	function exit() {
    	keepRunning = false;
	}

	function reload() {
		reloadshell = true;
    	keepRunning = false;
	}

	function getText() {
    	return reader.getCursorBuffer().toString();
	}

	function unescapeHTML(required html) {
    	var text = StringEscapeUtils.unescapeHTML(html);
    	text = replace(text,"<" & "br" & ">","","all");
       	return text;
	}

	function HTML2ANSI(required html) {
    	var text = replace(html,"<" & "br" & ">","","all");
    	var matches = REMatch('(?i)<b[^>]*>(.+?)</b>', text);
    	for(var match in matches) {
    		var boldtext = ansi("bold",reReplaceNoCase(match,"<b[^>]*>(.+?)</b>","\1"));
    		text = replace(text,match,boldtext,"one");
    	}
    	//request.debug(matches);
		//system.out.println(text);
    	//request.debug(text);
       	return text;
	}

	function pwd() {
    	return pwd;
	}

	function cd(directory="") {
		directory = replace(directory,"\","/","all");
		if(directory=="") {
			pwd = initialDirectory;
		} else if(directory=="."||directory=="./") {
			// do nothing
		} else if(directoryExists(directory)) {
	    	pwd = directory;
		} else {
			return "cd: #directory#: No such file or directory";
		}
		return pwd;
	}

	function ansi(required color, required string) {
		var colorFunction = ANSIBuffer.init();
    	return colorFunction[color](string).toString();
	}

    function run(input="") {
        var mask = "*";
        var trigger = "su";
        reloadshell = false;

		try{
	        if (input != "") {
	        	input &= chr(10);
	        	var inStream = createObject("java","java.io.ByteArrayInputStream").init(input.getBytes());
	        	reader.setInput(inStream);
	        }
	        reader.setBellEnabled(false);
	        //reader.setDebug(new PrintWriter(new FileWriter("writer.debug", true)));
			var commandHandler = new CommandHandler(this);

	        var line ="";
	        keepRunning = true;
			var shellPrompt = ansi("yellow","cfml> ");
			reader.setDefaultPrompt(shellPrompt);

	        while (keepRunning) {
				if(input != "") {
					keepRunning = false;
				}
				reader.printNewLine();
				try {
		        	line = reader.readLine();
				} catch (any er) {
					printError(er);
					// reload();
					continue;
				}
				if(trim(line) == "reload") {
					reload();
					continue;
				}
	            //reader.printString("======>" & line);
	            // If we input the special word then we will mask
	            // the next line.
	            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
	                line = reader.readLine("password> ", javacast("char",mask));
	            }
				var args = rematch("'.*?'|"".*?""|\S+",line);
				if(args.size() == 0 || len(trim(line))==0) continue;
				if(listFindNoCase(commandHandler.listCommands(),trim(args[1]))) {
					try{
						var result = commandHandler.runCommandLine(line);
						var result = isNull(result) ? "" : reader.printString(result);
					} catch (any e) { printError(e); }
					continue;
				} else {
					printError({message:"'#args[1]#' is unknown.  Did you mean one of these: #commandHandler.listCommands()#?"});
				}
	        }
	        if(structKeyExists(variables,"ansiOut")) {
	        	variables.ansiOut.close();
	        }
	        //out.close();
		} catch (any e) {
			printError(e);
	        if(structKeyExists(variables,"ansiOut")) {
	        	variables.ansiOut.close();
	        }
		}
		return reloadshell;
    }

	function printError(required err) {
		reader.printString(ansi("red","ERROR: ") & HTML2ANSI(err.message));
		if (structKeyExists( err, 'tagcontext' )) {
			var lines=arrayLen( err.tagcontext );
			if (lines != 0) {
				for(idx=1; idx<=lines; idx++) {
					tc = err.tagcontext[ idx ];
					if (len( tc.codeprinthtml )) {
						isFirst = ( idx == 1 );
						isFirst ? reader.printString(ansi("red","#tc.template#: line #tc.line#")) : reader.printString(ansi("magenta","#ansi('bold','called from ')# #tc.template#: line #tc.line#"));
						reader.printNewLine();
						reader.printString(ansi("blue",HTML2ANSI(tc.codeprinthtml)));
					}
				}
			}
		}
		reader.printNewLine();
	}

}