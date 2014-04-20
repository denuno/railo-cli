component output="false" persistent="false" trigger="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		cr = chr(10);
		return this;
	}

	/**
	 * Display help information
	 **/
	function help(String command="")  {
		var result = shell.ansi("green","CLI HELP") & cr;
		for(var fun in getMetadata(this).functions) {
			if(fun.name != "init") {
				result &= chr(9) & shell.ansi("cyan",fun.name) & " : " & fun.hint & cr;
				result &= chr(9) & shell.ansi("magenta","Arguments") & cr;
				for(var param in fun.parameters) {
					result &= chr(9);
					if(param.required)
						result &= shell.ansi("red","required ");
					result &= param.type & " ";
					result &= shell.ansi("magenta",param.name)
					if(!isNull(param.default))
						result &= "=" & param.default & " ";
					if(!isNull(param.hint))
						result &= " (#param.hint#)";
				 	result &= cr;
				}
				result &= cr;
			}
		}
		return result;
	}

	/**
	 * List directories
	 * 	ex: ls /my/path
	 **/
	function ls(String directory="", Boolean recurse=false)  {
		return dir(directory,recurse);
	}

	/**
	 * List directories
	 * 	ex: dir /my/path
	 **/
	function dir(String directory="", Boolean recurse=false)  {
		var result = "";
		directory = trim(directory) == "" ? shell.pwd() : directory;
		for(var d in directoryList(directory,recurse)) {
			result &= shell.ansi("cyan",d) & cr;
		}
		return result;
	}

	/**
	 * List directories
	 * 	ex: dir /my/path
	 **/
	function directory(String directory="", Boolean recurse=false)  {
		return dir(directory);
	}

	/**
	 * Get version
	 **/
	function version()  {
		return "1.0.0";
	}


	/**
	 * Set prompt
	 **/
	function prompt(required String prompt)  {
		reader.setDefaultPrompt(prompt);
		return "setting prompt";
	}

	/**
	 * print working directory (current dir)
	 **/
	function pwd()  {
		return shell.pwd();
	}

	/**
	 * change directory
	 **/
	function cd(directory="")  {
		return shell.cd(directory);
	}

	/**
	 * executes a cfml file
	 **/
	function execute(file="")  {
		return include(file);
	}

	/**
	 * Exit CLI
	 **/
	function exit()  {
		shell.exit();
		return "Peace out!";
	}

	/**
	 * Reload CLI
	 **/
	function reload()  {
		shell.reload();
		return "Reloading...";
	}


}