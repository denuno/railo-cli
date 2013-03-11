component output="false" persistent="false" {

	commands = {};
	extensions = {};

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
        var completors = createObject("java","java.util.LinkedList");
		loadCommands(new Commands(shell));
		loadExtensions();
		var completor = createDynamicProxy(new completor(this), ["jline.Completor"]);
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

	function loadCommands(cfc) {
		for(var fun in getMetadata(cfc).functions) {
			if(fun.name != "init") {
				commands[fun.name].cfc = cfc;
				commands[fun.name].parameters = fun.parameters;
			}
		}
	}

	function loadExtensions(){
		var varDirs = DirectoryList(expandPath("/tests/cfml/cli/plugins/"), false, "name");
		for(var dir in varDirs){
			if(DirectoryExists(expandPath("/tests/cfml/cli/plugins/#dir#"))){
				var cfc = createObject("tests.cfml.cli.plugins.#dir#.Main").init(shell);
				extensions[dir].cfc = cfc;
				for(var fun in getMetadata(cfc).functions) {
					if(fun.name != "init") {
						extensions[dir][fun.name].parameters = fun.parameters;
					}
				}
			}
		}
	}

	function runCommandline(line) {
		var args = rematch("'.*?'|"".*?""|\S+",line);
		var command = args[1];
		arrayDeleteAt(args,1);
		if(structKeyExists(commands,command)) {
			if(isNull(args) || arrayLen(args) == 0) {
				return commands[command].cfc[command]();
			} else {
				return commands[command].cfc[command](argumentCollection=args);
			}
		} else if (structKeyExists(extensions,command)) {
			var extension = command;
			if(isNull(args) || arrayLen(args) == 0) {
				return extensions[extension].cfc["help"]();
			} else {
abort;
				command = args[1];
				arrayDeleteAt(args,1);
				return extensions[extension].cfc[command](args);
			}
		} else {
			throw("could not find command '#command#'");
		}
	}

	function listCommands() {
		return structKeyList(commands) & "," & structKeyList(extensions);
	}

	function getCommands() {
		return commands;
	}

	function getExtensions(extension = "") {
		if(extension != "") {
			return extensions[extension];
		}
		return extensions;
	}

}