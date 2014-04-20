component output="false" persistent="false" {

	commandlist = createObject("java","java.util.TreeSet");

	function init(commandHandler) {
		variables.commandHandler = arguments.commandHandler;
		variables.commandlist.addAll(commandHandler.listCommands().split(','));
		variables.commands = commandHandler.getCommands();
	}

	function complete(String buffer, numeric cursor, candidates)  {
		var start = isNull(buffer) ? "" : buffer;
		var args = rematch("'.*?'|"".*?""|\S+",start);
		var prefix = args.size() > 0 && structKeyExists(commands,args[1]) ? args[1] : "";
		var startIndex = 0;
		var isArgument = false;
		var lastArg = args.size() > 0 ? args[args.size()] : "";
		variables.partialCompletion = false;
		if(prefix eq "") {
			command = args.size() > 0 ? args[1] : "";
		} else {
			if(arrayLen(args) >= 2) {
				command = args[2];
			} else if(!StructKeyExists(commands,prefix)) {
				return len(start);
			}
		}

		if(args.size() == 0 || arrayLen(args) == 1 && !start.endsWith(" ")) {
			// starting to type the prefix or command
        	candidates.clear();
	        for (var i = commandlist.iterator(); i.hasNext();) {
	            var can = i.next();
	            if (can.startsWith(start)) {
		            candidates.add(can);
	            }
	        }
		} else if (arrayLen(args) == 1 && start.endsWith(" ")) {
			// add prefix command list or command parameters
			if(len(prefix) > 0) {
				for(var param in commands[prefix]) {
	            	candidates.add(param);
				}
			} else {
				if(!StructKeyExists(commands,prefix) || !StructKeyExists(commands[prefix],command)) {
					return len(start);
				}
				for(var param in commands[prefix][command].parameters) {
	            	candidates.add(param.name);
				}
				isArgument = true;
			}
			startIndex = len(start);
		} else if(len(prefix) && arrayLen(args) == 2 && !start.endsWith(" ")) {
			// prefix command list
			for(var param in commands[prefix]) {
	            if (param.startsWith(lastArg)) {
            		candidates.add(param);
	            }
			}
			startIndex = len(start) - len(lastArg);
		} else if(arrayLen(args) > 1) {
			var parameters = "";
			var lastArg = args[arrayLen(args)];
			isArgument = true;
			parameters = commands[prefix][command].parameters;
			for(var param in parameters) {
				if(!start.endsWith(" ") && lastArg.startsWith("#param.name#=")) {
					var paramType = param.type;
					var paramSoFar = listRest(lastArg,"=");
					paramValueCompletion(param.name, paramType, paramSoFar, candidates);
					startIndex = len(start) - len(paramSoFar);
					isArgument = false;
				} else {
		            if (param.name.startsWith(lastArg) || start.endsWith(" ")) {
		            	if(!findNoCase(param.name&"=", start)) {
		            		candidates.add(param.name);
		            	}
		            }
					startIndex = start.endsWith(" ") || findNoCase("=",lastArg) ? len(start) : len(start) - len(lastArg);
					isArgument = true;
				}
			}
		}
        if (candidates.size() == 1 && !partialCompletion) {
        	can = isArgument ? candidates.first() & "=" : candidates.first() & " ";
        	candidates.clear();
        	candidates.add(can);
        }
        return (candidates.size() == 0) ? (-1) : startIndex;
	}

	private function paramValueCompletion(String paramName, String paramType, String paramSoFar, required candidates) {
		switch(paramType) {
			case "Boolean" :
           		treeAddIfMatch("true",paramSoFar,candidates);
           		treeAddIfMatch("false",paramSoFar,candidates);
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

	private function directoryCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandHandler.getShell().pwd();
		}
		var dirs = directoryList(getDirectoryFromPath(startsWith),false,"query");
		for(dir in dirs) {
			if(dir.type=="dir" && refindNoCase("^#startsWith#",dir.directory&"/"&dir.name)) {
				if(dir.name != "/") {
					candidates.add(dir.directory&"/"&dir.name&"/");
				} else {
					candidates.add(dir.directory);
				}
			}
		}
		variables.partialCompletion = true;
	}

	private function fileCompletion(String startsWith, required candidates) {
		startsWith = replace(startsWith,"\","/","all");
		if(startsWith == "") {
			startsWith = commandHandler.getShell().pwd();
		}
		var files = directoryList(getDirectoryFromPath(startsWith));
		for(file in files) {
			if(file.startsWith(startsWith)) {
				candidates.add(file);
			}
		}
	}

	private function treeAddIfMatch(required match, required startsWith, required tree) {
		match = lcase(match);
		startsWith = lcase(startsWith);
		if(match.startsWith(startsWith) || len(startsWith) == 0) {
			tree.add(match);
		}
	}

/*
	function init(commands) {
		variables.commands.addAll(arguments.commands.split(','));
	}

	function complete(String buffer, numeric cursor, candidates)  {
		var start = isNull(buffer) ? "" : buffer;
       	var matches = commands.tailSet(start);
        for (var i = matches.iterator(); i.hasNext();) {
            var can = i.next();
            if (!(can.startsWith(start))) {
                break;
            }
            candidates.add(can);
        }
        if (candidates.size() == 1) {
        	can = candidates.get(0) & " ";
        	candidates.clear();
        	candidates.add(can);
        }
        // the index of the completion is always from the beginning of
        // the buffer.
        return (candidates.size() == 0) ? (-1) : 0;
	}
*/

}