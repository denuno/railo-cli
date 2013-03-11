component output="false" persistent="false" {

	commands = createObject("java","java.util.TreeSet");
	extensions = createObject("java","java.util.TreeSet");

	function init(commandHandler) {
		variables.commandHandler = arguments.commandHandler;
		variables.commands.addAll(commandHandler.listCommands().split(','));
	}

	function complete(String buffer, numeric cursor, candidates)  {
		var start = isNull(buffer) ? "" : buffer;
		var args = rematch("'.*?'|"".*?""|\S+",start);

		if(arrayLen(args) > 2) {
			extensions.clear();
			extensions.addAll(structKeyList(commandHandler.getExtensions()).split(","));
       		var matches = extensions.tailSet(start);
		} else if(arrayLen(args) > 1 && args[1] == "help") {
       		var matches = commands.tailSet(start);
		} else if(arrayLen(args) > 1) {
       		var matches = commands.tailSet(start);
       		if(matches.size() == 0) {
				extensions.clear();
				extensions.addAll(structKeyList(commandHandler.getExtensions(args[1])).split(","));
	       		start = replaceNoCase(start,args[1] & " ","","one");
	       		matches = extensions.tailSet(start);
       		}
		} else {
       		var matches = commands.tailSet(start);
		}

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
//        request.debug(buffer);
//        request.debug(cursor);
//        request.debug(candidates);
        return (candidates.size() == 0) ? (-1) : 0;
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