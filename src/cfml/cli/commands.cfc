component output="false" persistent="false" trigger="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		return this;
	}

	/**
	 * Display help information
	 **/
	function help(String command="")  {
			reader.printString("HELP");
			reader.printNewLine();
			for(var fun in getMetadata(this).functions) {
				if(fun.name != "init") {
					reader.printString(fun.name & " : " & fun.hint);
				}
			}
	}

	/**
	 * List directories
	 * ex: ls /my/path
	 **/
	function ls(String path="")  {
		return dir(path);
	}

	/**
	 * List directories
	 * ex: dir /my/path
	 **/
	function dir(String path=".")  {
		for(var d in directoryList(path)) {
			reader.printString(d);
			reader.printNewLine();
		}
	}

}