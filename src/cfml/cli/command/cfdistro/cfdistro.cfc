component output="false" persistent="false" trigger="" {

	function init(shell) {
		variables.shell = shell;
		reader = shell.getReader();
		return this;
	}

	/**
	 * Generate war
	 * ex: war destination=/directory/to/store/in
	 **/
	function war(String destination="")  {
		return "generating war";
	}

	/**
	 * Get dependency
	 **/
	function dependency(required artifactId, required groupId, required version, mapping, exclusions="")  {
	}

}