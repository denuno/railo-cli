/**
 * completion handler
 * @author Denny Valliant
 **/
component output="false" persistent="false" {

	// command list, containing namespaceless commands and available namespaces
	commandlist = createObject("java","java.util.ArrayList");

	/**
	 * constructor
	 * @commandHandler.hint CommandHandler this completor is attached to
	 **/
	function init(commandHandler) {
		variables.commandHandler = arguments.commandHandler;
		variables.commandlist.addAll(commandHandler.listCommands().split(','));
		variables.commands = commandHandler.getCommands();
		variables.shell = commandHandler.getShell();
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @cursor.hint cursor position
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	function complete(co)  {
		try {
			_complete(co);
		} catch (any e) {
			shell.printError(e);
		}
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @cursor.hint cursor position
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	function getFormattedCompletionCandidates()  {
		try {
			_complete(co);
		} catch (any e) {
			shell.printError(e);
		}
	}

	/**
	 * populate completion candidates and return cursor position
	 * @buffer.hint text so far
	 * @cursor.hint cursor position
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	function _complete(co)  {
		candidates = createObject("java","java.util.ArrayList");
		var start = isNull(co.getBuffer()) ? "" : shell.unansi(co.getBuffer());
		var parsed = commandHandler.getParser().parse(start.replace(shell.unansi(shell.getPrompt()),""));
		var commandLine = parsed.tree;
		var prefix = isNull(commandLine.namespace()) ? "" : commandLine.namespace().getText();
		var command = commandLine.command().commandName().getText();
		var args = commandLine.command().arguments().argument();
		if(trim(command) == "<missing commandname>") {
			command = "";
		}
		var startIndex = 0;
		var isArgument = false;
		var lastArg = args.size() > 0 ? args[args.size()].getText() : "";
		if(args.size() == 0 && commandLine.command().arguments().getText().trim() != "") {
			lastArg = commandLine.command().arguments().getText().trim();
		}
		variables.partialCompletion = false;
		if(prefix == "" && command == "") {
			for(var can in commandList) {
	            if (can.startsWith(start) || start == "") {
	            	candidates.add(can);
				}
			}
		} else if(prefix != "" && command == "") {
			var typedSoFar = start.replace(prefix,"");
			if(typedSoFar=="") {
            	candidates.add(prefix);
			} else {
				typedSoFar = trim(typedSoFar);
				for(var commandName in commands[prefix]) {
	            	if (commandName.startsWith(typedSoFar) || typedSoFar == "") {
	            		candidates.add(commandName);
	            	}
				}
			}
		} else if(command != "" && args.size() == 0 && lastArg == "") {
			if(!start.endsWith(" ")) {
            	candidates.add(command);
			} else {
				for(var param in commands[prefix][command].parameters) {
	            	candidates.add(param.name & "=");
				}
			}
		} else if(command != "" && (args.size() > 0 || lastArg != "")) {
			parameters = commands[prefix][command].parameters;
			for(var param in parameters) {
				if(lastArg.startsWith("#param.name#=")) {
					var paramType = param.type;
					var paramSoFar = listRest(lastArg,"=");
					paramSoFar = paramSoFar.equals("<EOF>") ? "" : paramSoFar;
					paramValueCompletion(param.name, paramType, paramSoFar, candidates);
				} else {
		            if (param.name.startsWith(lastArg) || start.endsWith(" ")) {
		            	if(!findNoCase(param.name&"=", start)) {
		            		candidates.add(param.name & "=");
		            	}
		            }
				}
			}
		}
        if (candidates.size() == 1 && !partialCompletion) {
        	can = isArgument ? candidates.get(0) & "=" : candidates.get(0) & " ";
        	candidates.clear();
        	candidates.add(can);
        	shell.print(can);
        }
/*
		shell.println("");
		shell.println(start);
		shell.println(candidates);
*/
        co.setCompletionCandidates(candidates);
        return;
        return (candidates.size() == 0) ? (-1) : startIndex;
	}

	/**
	 * populate completion candidates for parameter values
	 * @paramName.hint param name
	 * @paramType.hint type of parameter (boolean, etc.)
	 * @paramSoFar.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function paramValueCompletion(String paramName, String paramType, String paramSoFar, required candidates) {
		switch(paramType) {
			case "Boolean" :
           		addCandidateIfMatch("true",paramSoFar,candidates);
           		addCandidateIfMatch("false",paramSoFar,candidates);
				break;
		}
		switch(paramName) {
			case "directory" :
			case "destination" :
           		directoryCompletion(paramSoFar,candidates);
				break;
			case "file" :
           		fileCompletion(paramSoFar,candidates);
				break;
		}
	}

	/**
	 * populate directory parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function directoryCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandHandler.getShell().pwd();
		}
		var files = directoryList(getDirectoryFromPath(startsWith));
		for(file in files) {
			if(file.startsWith(startsWith)) {
				if(directoryExists(file))
					candidates.add(file&"/");
			}
		}
		variables.partialCompletion = true;
	}

	/**
	 * populate file parameter value completion candidates
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function fileCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandHandler.getShell().pwd();
		}
		var files = directoryList(getDirectoryFromPath(startsWith));
		for(file in files) {
			if(file.startsWith(startsWith)) {
				if(fileExists(file))
					candidates.add(file);
			}
		}
	}

	/**
	 * add a value completion candidate if it matches what was typed so far
	 * @match.hint text to compare as match
	 * @startsWith.hint text typed so far
	 * @candidates.hint tree to populate with completion candidates
 	 **/
	private function addCandidateIfMatch(required match, required startsWith, required candidates) {
		match = lcase(match);
		startsWith = lcase(startsWith);
		if(match.startsWith(startsWith) || len(startsWith) == 0) {
			candidates.add(match);
		}
	}

}