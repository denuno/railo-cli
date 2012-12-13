<cfsilent>
<cfset _shellprops = { version:'0.1' } >
<cfsetting requesttimeout="9999" />
<cfsavecontent variable="_shellprops.help">Live evaluation (with GNU Readline-ish input control)
	Empty line displays and evaluates current buffer.  'version' lists version, 'clear' clears buffer, 'ls' and 'dir' list files, 'exit', 'quit', 'q' exits.  There is tab-completion, hit tab to see all.
	Examples:
		wee=3+4+5
		foo="bar"
		"re" & foo
		server.railo.version
		serialize(server.coldfusion)
</cfsavecontent>
<cfscript>
	System = createObject("java", "java.lang.System");
	keepRunning = true;
	script = "";
	systemOutput(_shellprops.help);
	jline();
    function jline() {
        var mask = "*";
        var trigger = "su";
        var reader = createObject("java","jline.ConsoleReader");
        reader.setBellEnabled(false);
        //reader.setDebug(new PrintWriter(new FileWriter("writer.debug", true)));
        var completors = createObject("java","java.util.LinkedList");
        completors.add(createObject("java","jline.SimpleCompletor").init(
        	["clear","exit","ls","dir","version","server.coldfusion.productname","server.railo.version"]
       	));

        reader.addCompletor(createObject("java","jline.ArgumentCompletor").init(completors));

        var line ="";
        var out = createObject("java","java.io.PrintWriter").init(System.out);

        while (keepRunning) {
			systemOutput(chr(10));
        	line = reader.readLine("prompt> ");
            out.println("======>" & line);
            out.flush();
            // If we input the special word then we will mask
            // the next line.
            if ((!isNull(trigger)) && (line.compareTo(trigger) == 0)) {
                line = reader.readLine("password> ", javacast("char",mask));
            }
			var args = line.split(" ");
			switch(args[1]) {
				case "clear":
					script = "";
					break;

				case "version":
					systemOutput(_shellprops.version & chr(10));
					break;

				case "dir": case "ls":
					dir = isNull(args[2]) ? "." : args[2];
					for(dir in directoryList(dir)) {
						systemOutput(dir & chr(10)) ;
					}
					break;

				case "exit": case "quit": case "q":
					systemOutput("Peace out!");
					keepRunning = false;
					break;

				case "":
					try{
						systemOutput(script);
						systemOutput(evaluate(script));
					} catch (any e) {
						systemOutput("error: " & e.message & chr(10));
					}
					break;

				default:
					try{
						systemOutput(line & " = " & evaluate(line) & chr(10));
						script &= line  & chr(10);
					} catch (any e) {
						systemOutput("error: " & e.message & chr(10));
					}
					break;

			}

        }
    }

</cfscript>
</cfsilent>