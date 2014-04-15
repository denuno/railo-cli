component {

	System = createObject("java", "java.lang.System");
	ANSIBuffer = createObject("java", "jline.ANSIBuffer");
    StringEscapeUtils = createObject("java","org.apache.commons.lang.StringEscapeUtils");
	keepRunning = true;
	script = "";

	function init(inStream, printWriter) {
		if(isNull(printWriter)) {
			if(findNoCase("windows",server.os.name)) {
				variables.ansiOut = createObject("java","org.fusesource.jansi.AnsiConsole").out;
        		var printWriter = createObject("java","java.io.PrintWriter").init(
        			createObject("java","java.io.OutputStreamWriter").init(variables.ansiOut,
        			// default to Cp850 encoding for Windows console output (ROO-439)
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

	function stop() {
    	keepRunning = false;
	}

	function getText() {
    	return reader.getCursorBuffer().toString();
	}

	function ansi(required color, required string) {
		var colorFunction = ANSIBuffer.init();
    	return colorFunction[color](string).toString();
	}

    function run(input="") {
        var mask = "*";
        var trigger = "su";
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
	        	line = reader.readLine();
	            //reader.printString("======>" & line);
	            // If we input the special word then we will mask
	            // the next line.
	            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
	                line = reader.readLine("password> ", javacast("char",mask));
	            }
				var args = rematch("'.*?'|"".*?""|\S+",line);
				if(listContains(commandHandler.listCommands(),args[1])) {
					try{
						commandHandler.runCommandLine(line);
					} catch (any e) { printError(e); }
					continue;
				}
	//			request.debug("NOHANDLER");
				switch(args[1]) {
					case "clear":
						script = "";
						break;

					case "version":
						reader.printString(_shellprops.version & chr(10));
						break;

					case "exit": case "quit": case "q":
						reader.printString("Peace out!");
						keepRunning = false;
						break;

					case "":
						reader.printString(script);
						reader.printString(evaluate(script));
						break;

					default:
						try {
							reader.printString(line & " = " & evaluate(line) & chr(10));
							script &= line  & chr(10);
						} catch (any e) {
							printError(e);
						}
						break;
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
    }

	function printError(required err) {
		reader.printString(ansi("red","error:") &  #e.message#);
		if (structKeyExists( err, 'tagcontext' )) {
			var lines=arrayLen( err.tagcontext );
			if (lines != 0) {
				for(idx=1; idx<=lines; idx++) {
					tc = err.tagcontext[ idx ];
					if (len( tc.codeprinthtml )) {
						isFirst = ( idx == 1 );
						isFirst ? reader.printString(ansi("red","*#tc.template#: line #tc.line#*")) : reader.printString(ansi("magenta","#ansi('bold','called from')# #tc.template#: line #tc.line#"));
						reader.printNewLine();
						reader.printString(ansi("blue",tc.codeprinthtml));
					}
				}
			}
		}
		reader.printNewLine();
	}

}