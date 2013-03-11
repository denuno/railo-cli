component {

	System = createObject("java", "java.lang.System");
	keepRunning = true;
	script = "";

	function init(inStream, printWriter) {
		if(isNull(printWriter)) {
			//new PrintWriter(OutputStreamWriter(System.out,System.getProperty("jline.WindowsTerminal.output.encoding",System.getProperty("file.encoding"))));
	    	reader = createObject("java","jline.ConsoleReader").init();
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

    function run(input="") {
        var mask = "*";
        var trigger = "su";
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
        while (keepRunning) {
			if(input != "") {
				keepRunning = false;
			}
			reader.printNewLine();
        	line = reader.readLine("cfml>");
            //reader.printString("======>" & line);
            // If we input the special word then we will mask
            // the next line.
            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
                line = reader.readLine("password> ", javacast("char",mask));
            }
			var args = rematch("'.*?'|"".*?""|\S+",line);
			if(listContains(commandHandler.listCommands(),args[1])) {
				commandHandler.runCommandLine(line);
				continue;
			}
			request.debug("NOHANDLER");
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
					try{
						reader.printString(script);
						reader.printString(evaluate(script));
					} catch (any e) {
						reader.printString("error: " & e.message & chr(10));
					}
					break;

				default:
					try{
						reader.printString(line & " = " & evaluate(line) & chr(10));
						script &= line  & chr(10);
					} catch (any e) {
						reader.printString("error: " & e.message & chr(10));
					}
					break;

			}

        }
        //out.close();
    }

}