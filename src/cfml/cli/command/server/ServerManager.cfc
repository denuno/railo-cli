component {

	java = {
		ServerSocket : createObject("java","java.net.ServerSocket")
		, File : createObject("java","java.io.File")
		, Socket : createObject("java","java.net.Socket")
		, InetAddress : createObject("java","java.net.InetAddress")
		, LaunchUtil : createObject("java","runwar.LaunchUtil")
	}

	function init(shell) {
		variables.shell = shell;
		variables.libdir = shell.getHomeDir() & "/lib";
		variables.serverConfig = shell.getProfileDir() & "/servers.json";
		if(!fileExists(serverConfig)) {
			fileWrite(serverConfig,"{}");
		}
		return this;
	}

	/**
	 * Start a server instance
	 *
	 * @serverInfo.hint struct of server info (ports, etc.)
	 * @background.hint start server in background
  	 * @openbrowser.hint open a browser after starting
	 * @force.hint force start if status is not stopped
	 * @debug.hint sets debug log level
	 **/
	function start(Struct serverInfo, Boolean background=false, Boolean openBrowser=false, Boolean force=false, Boolean debug=false)  {
		var launchUtil = java.LaunchUtil;
		var webroot = serverInfo.webroot;
		var webhash = hash(serverInfo.webroot);
		var name = serverInfo.name is "" ? listLast(webroot,"\/") : serverInfo.name;
		var portNumber = serverInfo.port == 0 ? getRandomPort() : serverInfo.port;
		var socket = serverInfo.stopsocket == 0 ? getRandomPort() : serverInfo.stopsocket;
		var jarPath = java.File.init(launchUtil.class.getProtectionDomain().getCodeSource()
				.getLocation().toURI().getSchemeSpecificPart()).getAbsolutePath();
		var logdir = shell.getHomeDir() & "/server/log/" & name;
		var processName = name is "" ? "cfml" : name;
		var command = launchUtil.getJreExecutable().getCanonicalPath();
		var args = "-javaagent:""#libdir#/railo-inst.jar"" -jar ""#jarPath#"""
				& " -war ""#webroot#"" --background #background# --port #portNumber# --debug #debug#"
				& " --stop-port #socket# --processname ""#processName#"" --log-dir ""#logdir#"""
				& " --cfengine-name railo --open-browser #openbrowser# --open-url http://127.0.0.1:#portNumber#"
				& " --lib-dirs ""#variables.libdir#"" --tray-icon ""#variables.libdir#/trayicon.png""";
		serverInfo.port = portNumber;
		serverInfo.stopsocket = socket;
		serverInfo.logdir = logdir;
		if(!directoryExists(logdir)) {
			directoryCreate(logdir,true);
		}
		setServerInfo(serverInfo);
		if(serverInfo.status == "stopped" || force) {
			serverInfo.status = "starting";
			setServerInfo(serverInfo);
			if(!background) {
				return launch(serverInfo, command, args);
			} else {
				thread name="server#webhash##createUUID()#" serverInfo=serverInfo command=command args=args {
					launch(serverInfo, command, args);
				}
			}
			return "The server for #webroot# is starting on port #portNumber#... type 'server status' to see result";
		} else {
			return "Cannot start!  The server is currently in the #serverInfo.status# state!#chr(10)#Use force=true or the 'server forget' command ";
		}
	}

	/**
	 * Launch a server instance
	 *
	 * @serverInfo.hint struct of server info (ports, etc.)
	 * @command.hint web root for this server
	 * @args.hint short name for this server
	 **/
	private function launch(Struct serverInfo, String command, String args)  {
		try{
			if(find(" ",command) && !command.endsWith('"')) {
				command = '"#command#"';
			}
			execute name=command arguments=args timeout="50" variable="executeResult";
			serverInfo.statusInfo = {command:command,arguments:args,result:executeResult};
			serverInfo.status="running";
			setServerInfo(serverInfo);
			return executeResult;
		} catch (any e) {
			serverInfo.statusInfo.result &= executeResult;
			serverInfo.status="unknown";
			setServerInfo(serverInfo);
		}
		return "";
	}

	/**
	 * Stop server
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function stop(Struct serverInfo)  {
		var launchUtil = java.LaunchUtil;
		var jarPath = java.File.init(launchUtil.class.getProtectionDomain().getCodeSource()
				.getLocation().toURI().getSchemeSpecificPart()).getAbsolutePath();
		var command = launchUtil.getJreExecutable().getCanonicalPath();
		var stopsocket = serverInfo.stopsocket;
		var args = "-jar ""#jarPath#"" -stop --stop-port #val(stopsocket)# --background false";
		try{
			execute name=command arguments=args timeout="50" variable="executeResult";
			serverInfo.status = "stopped";
			serverInfo.statusInfo = {command:command,arguments:args,result:executeResult};
			setServerInfo(serverInfo);
			return executeResult;
		} catch (any e) {
			serverInfo.status = "unknown";
			serverInfo.statusInfo = {command:command,arguments:args,result:executeResult & e.message};
			setServerInfo(serverInfo);
			return e.message;
		}
	}

	/**
	 * Forget server
	 * @serverInfo.hint struct of server info (ports, etc.)
	 * @all.hint remove ALL servers
 	 **/
	function forget(Struct serverInfo, Boolean all=false)  {
		if(!all) {
			servers = getServers();
			structDelete(servers,hash(serverInfo.webroot));
			setServers(servers);
		} else {
			setServers({});
		}
	}

	/**
	 * Get a random port for the specified host
	 * @host.hint host to get port on, defaults 127.0.0.1
 	 **/
	function getRandomPort(host="127.0.0.1") {
		var nextAvail = java.ServerSocket.init(0, 1, java.InetAddress.getByName(host));
		var portNumber = nextAvail.getLocalPort();
		nextAvail.close();
		return portNumber;
	}

	/**
	 * persist server info
	 * @serverInfo.hint struct of server info (ports, etc.)
 	 **/
	function setServerInfo(Struct serverInfo) {
		// TODO: prevent race conditions  :)
		var servers = getServers();
		var webrootHash = hash(serverInfo.webroot);
		if(serverInfo.webroot == "") {
			throw("The webroot cannot be empty!");
		}
		servers[webrootHash] = serverInfo;
		setServers(servers);
	}

	/**
	 * persist servers
	 * @servers.hint struct of serverInfos
 	 **/
	function setServers(Struct servers) {
		// TODO: prevent race conditions  :)
		fileWrite(serverConfig,shell.formatJson(serializeJSON(servers)));
	}

	/**
	 * get servers struct
 	 **/
	function getServers() {
		if(fileExists(serverConfig)) {
			return deserializeJSON(fileRead(serverConfig));
		} else {
			return {};
		}
	}

	/**
	 * Get server info for webroot
	 * @webroot.hint root directory for served content
 	 **/
	function getServerInfo(webroot) {
		var servers = getServers();
		var webrootHash = hash(webroot);
		var statusInfo = {};
		if(!directoryExists(webroot)) {
			statusInfo = {result:"Webroot does not exist, cannot start :" & webroot };
		}
		if(isNull(servers[webrootHash])) {
			servers[webrootHash] = {
				webroot:webroot,
				port:"",
				stopsocket:"",
				debug:false,
				status:"stopped",
				statusInfo:{result:""},
				name:listLast(webroot,"\/")
			}
			setServers(servers);
		}
		return servers[webrootHash];
	}

}
