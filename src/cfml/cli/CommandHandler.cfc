component output="false" persistent="false" {

	commands = {};
	thisdir = getDirectoryFromPath(getMetadata(this).path);

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
        var completors = createObject("java","java.util.LinkedList");
		initCommands();
		var completor = createDynamicProxy(new Completor(this), ["jline.Completor"]);
        reader.addCompletor(completor);
/*
//        reader.addCompletor(createObject("java","jline.MultiCompletor").init([completor]));

 		var completor2 = createDynamicProxy(new completor("bello,bell,belli"), ["jline.Completor"]);
        completors.add(createObject("java","jline.MultiCompletor").init([completor,completor2]));

        completors.add(createObject("java","jline.SimpleCompletor").init(
        	["clear","exit","version","server.coldfusion.productname","server.railo.version"]
       	));
        completors.add(createObject("java","jline.FileNameCompletor").init());

        reader.addCompletor(createObject("java","jline.ArgumentCompletor").init(completors));
*/
		return this;
	}

	function initCommands() {
		var varDirs = DirectoryList(thisdir&"/command", false, "name");
		for(var dir in varDirs){
			if(listLast(dir,".") eq "cfc") {
				loadCommands("","command.#listFirst(dir,'.')#");
			} else {
				loadCommands(dir,"command.#dir#.#dir#");
			}
		}
	}

	function loadCommands(prefix,cfc) {
		var cfc = createObject(cfc).init(shell);
		for(var fun in getMetadata(cfc).functions) {
			if(fun.name != "init") {
				commands[prefix][fun.name].cfc = cfc;
				commands[prefix][fun.name].parameters = fun.parameters;
			}
		}
	}

	function getShell() {
		return variables.shell;
	}

	function runCommandline(line) {
		var args = rematch("'.*?'|"".*?""|\S+",line);
		var prefix = structKeyExists(commands,args[1]) ? args[1] : "";
 		if(prefix eq "") {
			command = args[1];
			arrayDeleteAt(args,1);
		} else {
			if(arrayLen(args) >= 2) {
				command = args[2];
				arrayDeleteAt(args,1);
				arrayDeleteAt(args,1);
			} else {
				if(!StructKeyExists(commands,prefix)) {
					shell.printError({message:"'#prefix#' is unknown.  Did you mean one of these: #listCommands()#?"});
					return;
				}
				if(structKeyExists(commands[prefix],prefix)) {
					command = prefix;
					arrayDeleteAt(args,1);
				} else {
					return "available actions: #structKeyList(commands[prefix])#";
				}
			}
		}
		if(!StructKeyExists(commands[prefix],command)) {
			shell.printError({message:"'#prefix# #command#' is unknown.  Did you mean one of these: #structKeyList(commands[prefix])#?"});
			return;
		}
		if(isNull(args) || arrayLen(args) == 0) {
			return commands[prefix][command].cfc[command]();
		} else {
			var namedArgs = {};
			for(var param in commands[prefix][command].parameters) {
            	for(var arg in args) {
            		if(findNoCase(param.name&"=",arg)) {
	            		namedArgs[param.name] = replaceNoCase(arg,"#param.name#=","");
            		}
            	}
			}
			if(len(StructKeyList(namedArgs))) {
				return commands[prefix][command].cfc[command](argumentCollection=namedArgs);
			}
			return commands[prefix][command].cfc[command](argumentCollection=args);
		}
	}

	function listCommands() {
		return listAppend(structKeyList(commands[""]),structKeyList(commands));
	}

	function getCommands() {
		return commands;
	}

}