package cliloader;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.FilenameFilter;
import java.io.PrintStream;
import java.io.PrintWriter;
import java.lang.reflect.Method;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.io.InputStream;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.LinkedList;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Properties;

public class LoaderCLIMain {

	private static String LIB_ZIP_PATH = "libs.zip";
	private static String CFML_ZIP_PATH = "cfml.zip";
	private static String ENGINECONF_ZIP_PATH = "engine.zip";
	private static String VERSION_PROPERTIES_PATH = "cliloader/version.properties";
	private static ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
	private static Boolean debug = false;
	private static int exitCode = 0;
    private static Boolean isBackground;
    private static File webRoot;
    private static File libDirectory;
    private static File railoConfigServerDirectory;
    private static File railoConfigWebDirectory;
    private static String name;
    private static String shellPath;
    private static File CLI_HOME;
    private static URLClassLoader _classLoader;
    private static String CR = System.getProperty("line.separator").toString();

	@SuppressWarnings("static-access")
    public static void main(String[] arguments) throws Throwable {
	    System.setProperty("apple.awt.UIElement","true");
	    ArrayList<String> cliArguments = new ArrayList<String>(Arrays.asList(arguments));
	    File cli_home;
        Boolean updateLibs = false;
        Boolean startServer = false;
        Boolean stopServer = false;
        Properties props = new Properties(), userProps = new Properties();
        if(listContains(cliArguments,"-debug") > 0) {
            debug = true;
            listRemoveContaining(cliArguments,"-debug");
            arguments = removeElement(arguments,"-debug");
        }
		try {
	        props.load(classLoader.getSystemResourceAsStream("cliloader/cli.properties"));
	    } catch (IOException e) { e.printStackTrace(); }
        log.debug("initial arguments:"+Arrays.toString(arguments));
		Map<String,String> config=toMap(arguments);
		String name = props.getProperty("name") != null ? props.getProperty("name") : "railo";
		setName(name);
		log.debug("cfml.cli.name: "+name);
		String version = props.getProperty("version") != null ? props.getProperty("version") : "0.0.0.0";
        setShellPath(props.getProperty("shell") != null ? props.getProperty("shell") : "/cfml/cli/shell.cfm");

        cli_home = getCLI_HOME(cliArguments, props, arguments, config);

        log.debug("initial cfml.cli.home: "+cli_home);
		if(!cli_home.exists()) {
		    System.out.println("Configuring "+name+" "+version+" home: "+ cli_home + " (change with -"+name+"_home=/path/to/dir)");
		    cli_home.mkdir();
		}
		
        if(new File(cli_home,"user.properties").exists()){
            FileInputStream fi = new FileInputStream(new File(cli_home,"user.properties"));
            userProps.load(fi);
            fi.close();
        } else {
//            userProps.put("cfml.cli.home", cli_home.getAbsolutePath());
//            FileOutputStream fo = new FileOutputStream(new File(cli_home,"user.properties"));
//            userProps.store(fo,null);
        }

		setLibDir(new File(cli_home,"lib").getCanonicalFile());
		
		// update/overwrite libs
		if(listContains(cliArguments,"-update") > 0) {
			System.out.println("updating "+name+" home");
			updateLibs = true;
			listRemoveContaining(cliArguments,"-update");
			arguments = removeElement(arguments,"-update");
		}
		
        // background
        if(listContains(cliArguments,"-background") > 0) {
            setBackground(true);
            arguments = removeElement(arguments,"-background");
        } else {
            setBackground(false);
        }

        if(listContains(cliArguments,"-stop") > 0) {
			stopServer = true;
			setBackground(false);
		}
		
		if(!updateLibs && (listContains(cliArguments,"-?")  > 0 || listContains(cliArguments,"-help") > 0)) {
			System.out.println(props.get("usage").toString().replace("/n",CR));
			Thread.sleep(1000);
			System.exit(0);
		}
		
		// railo libs dir
		if(listContains(cliArguments,"-lib") > 0) {
			String strLibs=config.get("lib");
			setLibDir(new File(strLibs));
			arguments = removeElementThenAdd(arguments,"-lib=",null);
			listRemoveContaining(cliArguments,"-lib");
		}

		if(listContains(cliArguments,"-server") > 0) {
			startServer=true;
		}

        if(listContains(cliArguments,"-webroot")  > 0 && config.get("webroot") != null) {
            arguments = removeElement(arguments,"-webroot");
            setWebRoot(new File(config.get("webroot")).getCanonicalFile());
        } else {
            if(getCurrentDir() != null) {
                setWebRoot(new File(getCurrentDir()).getCanonicalFile());
            } else {
                setWebRoot(new File("./").getCanonicalFile());
            }
        }
		
		if(listContains(cliArguments,"-shellpath") > 0) {
            int shellpathIdx = listContains(cliArguments,"-shellpath");
            String shellpath = cliArguments.get(shellpathIdx);
            if(shellpath.indexOf('=') == -1) {
                setShellPath(cliArguments.get(shellpathIdx+1));
                cliArguments.remove(shellpathIdx+1);
                cliArguments.remove(shellpathIdx);
            } else {
                setShellPath(shellpath.split("=")[1]);               
                cliArguments.remove(shellpathIdx);
            }
		    arguments = removeElement(arguments,"-shellpath");
		}
        props.setProperty("cfml.cli.shell", getShellPath());

        if(listContains(cliArguments,"-shell") > 0) {
            startServer=false;
            log.debug("we will be running the shell");
            arguments = removeElement(arguments,"-shell");
            listRemoveContaining(cliArguments,"-shell");
        }

		File libDir = getLibDir();
		props.setProperty("cfml.cli.lib", libDir.getAbsolutePath());
		
		// clean out any leftover pack files (an issue on windows)
		if(libDir.exists() && libDir.listFiles(new ExtFilter(".gz")).length > 0){
			for(File gz : libDir.listFiles(new ExtFilter(".gz"))) {
				try { gz.delete(); } catch (Exception e) {}
			}
		}

		if (!libDir.exists() || libDir.listFiles(new ExtFilter(".jar")).length < 2 
				|| updateLibs) {
			System.out.println("Library path: " + libDir);
			System.out.println("Initializing libraries -- this will only happen once, and takes a few seconds...");
			Util.unzipInteralZip(classLoader, LIB_ZIP_PATH, libDir, debug);
			Util.unzipInteralZip(classLoader, CFML_ZIP_PATH, new File(cli_home.getPath()+"/cfml"), debug);
			Util.unzipInteralZip(classLoader, ENGINECONF_ZIP_PATH, new File(cli_home.getPath()+"/engine"), debug);
			Util.copyInternalFile(classLoader, "resource/trayicon.png", new File(libDir,"trayicon.png"));
            Util.copyInternalFile(classLoader, VERSION_PROPERTIES_PATH, new File(libDir,"version.properties"));
			System.out.println("");
			System.out.println("Libraries initialized");
			if(updateLibs && arguments.length == 0) {
				System.out.println("updated! ctrl-c now or wait a few seconds for exit..");
				System.exit(0);
			}
		}
		
		if(libDir.exists()){
		    File versionFile = new File(libDir,"version.properties");
		    if(versionFile.exists()){
		        try{
		            String installedVersion = Util.readFile(versionFile.getPath()).trim();
		            String currentVersion = Util.getResourceAsString(VERSION_PROPERTIES_PATH).trim();
		            if(!installedVersion.equals(currentVersion)){
		                log.warn("Current version and installed versions do not match! /n   current: "
		                        +currentVersion + "\n installed: " + installedVersion 
		                        + "/nrun '"+ name + " -update' to install new version");
		            }
		        } catch (Exception e) {
		            log.warn("could not determine version: " + e.getMessage());
		        }
		    } else {
		        log.debug("no version.properties: " + versionFile.getAbsolutePath());
		    }
		}
		
		File configServerDir=new File(libDir.getParentFile(),"engine/railo/");
		File configWebDir=new File(libDir.getParentFile(),"engine/railo/railo-web");
		setRailoConfigServerDir(configServerDir);
        setRailoConfigWebDir(configWebDir);
		props.setProperty("cfml.cli.home", cli_home.getAbsolutePath());
		props.setProperty("cfml.cli.pwd", getCurrentDir());
		props.setProperty("railo.config.server", configServerDir.getAbsolutePath());
		props.setProperty("railo.config.web", configWebDir.getAbsolutePath());
		props.setProperty("cfml.server.trayicon", libDir.getAbsolutePath() + "/trayicon.png");
        props.setProperty("cfml.server.dockicon","");
        for (Iterator<?> iterator = props.keySet().iterator(); iterator.hasNext();) {
            String key = (String) iterator.next();
            String value = props.get(key).toString();
            System.setProperty(key, value);
            log.debug(key + ": " + value);
        }
//      Thread shutdownHook = new Thread( "cli-shutdown-hook" ) { public void run() { cl.close(); } };
//      Runtime.getRuntime().addShutdownHook( shutdownHook );   

        if(!startServer && !stopServer) {
            execute(cliArguments);
            System.exit(exitCode);
        } else {
            startRunwarServer(arguments, config);
        } 
	}
	
    private static void execute(ArrayList<String> cliArguments) throws ClassNotFoundException, NoSuchMethodException, SecurityException, IOException {
	    log.debug("Running in CLI mode");
	    System.setIn(new NonClosingInputStream(System.in));
	    String uri = null;
	    if(new File(getCLI_HOME(),getShellPath()).exists()) {
	        uri = new File(getCLI_HOME(),getShellPath()).getCanonicalPath();
	    } else if(new File(getShellPath()).exists()) {
            uri = new File(getShellPath()).getCanonicalPath();
	    } else {
	        log.error("Could not find shell:"+getShellPath());
	        exitCode = 1;
	        return;
	    }
        if(cliArguments.size() > 1 && cliArguments.contains("execute")) {
            // bypass the shell for running pure CFML files
            int executeIndex = cliArguments.indexOf("execute");
            File cfmlFile = new File(cliArguments.get(executeIndex+1));
            if(cfmlFile.exists()) {
                uri = cfmlFile.getCanonicalPath();
            }
            cliArguments.remove(executeIndex+1);
            cliArguments.remove(executeIndex);
            log.debug("Executing: "+uri);
        } else if(cliArguments.size() > 0 && new File(cliArguments.get(0)).exists()) {
            String filename = cliArguments.get(0);
            // this will force the shell to run the execute command
            if(filename.endsWith(".rs") || filename.endsWith(".boxr")) {
                log.debug("Executing batch file: "+filename);
                cliArguments.add(0, "recipe");
            } else {
                File cfmlFile = new File(filename);
                if(cfmlFile.exists()) {
                    log.debug("Executing file: "+filename);
                    uri = cfmlFile.getCanonicalPath();
                    cliArguments.remove(0);
                }
            }
            // handle bash script
            uri = removeBinBash(uri);
        } else {
            if(debug) System.out.println("uri: "+uri);
        }

        System.setProperty("cfml.cli.arguments",arrayToList(cliArguments.toArray(new String[cliArguments.size()])," "));
        if(debug) System.out.println("cfml.cli.arguments: "+Arrays.toString(cliArguments.toArray()));

        InputStream originalIn = System.in;
        PrintStream originalOut = System.out;

        URLClassLoader cl = getClassLoader();
        try{
            Class<?> cli;
            cli = cl.loadClass("railocli.CLIMain");
            Method run = cli.getMethod("run",new Class[]{File.class,File.class,File.class,String.class,boolean.class});
            File webroot=new File(getPathRoot(uri)).getCanonicalFile();
            run.invoke(null, webroot,getRailoConfigServerDir(),getRailoConfigWebDir(),uri,debug);
        } catch (Exception e) {
            exitCode = 1;
            e.getCause().printStackTrace();
        }
        cl.close();
        System.out.flush();
        System.setOut(originalOut);
        System.setIn(originalIn);
	}

    private static void startRunwarServer(String[] args, Map<String,String> config) throws ClassNotFoundException, NoSuchMethodException, SecurityException, IOException {
        System.setProperty("apple.awt.UIElement","false");
        log.debug("Running in server mode");
        //only used for server mode, cli root is /
        File webRoot = getWebRoot();
        String path = LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath();
        //System.out.println("yum from:"+path);
        String decodedPath = java.net.URLDecoder.decode(path, "UTF-8");
        decodedPath = new File(decodedPath).getPath();

        //args = removeElementThenAdd(args,"-server","-war "+webRoot.getPath()+" --background false --logdir " + libDir.getParent());
        String name = getName();
        File libDir = getLibDir(), configServerDir = getRailoConfigServerDir(), configWebDir = getRailoConfigWebDir();
        String[] addArgs;
        if(isBackground()) {
            addArgs= new String[] {
                    "-war",webRoot.getPath(),
                    "--railoserver",configServerDir.getAbsolutePath(),
                    "--railoweb",configWebDir.getAbsolutePath(),
                    "--background","true",
                    "--iconpath",libDir.getAbsolutePath() + "/trayicon.png",
                    "--libdir",libDir.getPath(),
                    "--debug",Boolean.toString(debug),
                    "--processname",name
                    };
        } else {
            addArgs= new String[] {
                    "-war",webRoot.getPath(),
                    "--railoserver",configServerDir.getAbsolutePath(),
                    "--railoweb",configWebDir.getAbsolutePath(),
                    "--iconpath",libDir.getAbsolutePath() + "/trayicon.png",
                    "--libdir",libDir.getPath(),
                    "--background","false",
                    "--debug",Boolean.toString(debug),
                    "--processname",name
                    };
        }
        args = removeElementThenAdd(args,"-server",addArgs);
        if(debug) System.out.println("Server args: " + arrayToList(args," "));
//        runwarURL[1] = libDir.listFiles(new PrefixFilter("railocli"))[0].toURI().toURL();
//        URLClassLoader rrcl = new URLClassLoader(runwarURL,ClassLoader.getSystemClassLoader());
//        URLClassLoader cl = new URLClassLoader(runwarURL,null);
//        URLClassLoader empty = new URLClassLoader(new URL[0],null);
//        XercesFriendlyURLClassLoader cl = new XercesFriendlyURLClassLoader(urls,null);
//        Thread.currentThread().setContextClassLoader(cl);
        Class<?> runwar;
        URLClassLoader cl = getClassLoader();
        try{
            runwar = cl.loadClass("runwar.Server");
            Method startServer = runwar.getMethod("startServer",new Class[]{String[].class, URLClassLoader.class});
            startServer.invoke(runwar.getConstructor().newInstance(), new Object[]{args, cl});
        } catch (Exception e) {
            exitCode = 1;
            if(e.getCause() != null) {
                e.getCause().printStackTrace();
            } else {
                e.printStackTrace();
            }
        }
        cl.close();
	}

    private static String removeBinBash(String uri) throws IOException {
        FileReader namereader = new FileReader(new File(uri));
        BufferedReader in = new BufferedReader(namereader);
        String line = in.readLine();
        if(line != null && line.startsWith("#!")) {
            File tmpfile = new File(uri+".tmp");
            tmpfile.deleteOnExit();
            PrintWriter writer = new PrintWriter(tmpfile);
            while ((line = in.readLine()) != null) {
                //writer.println(line.replaceAll(oldstring,newstring));
                writer.println(line);
            }
            uri += ".tmp";
            writer.close();
        }
        in.close();
        return uri;
    }

    private static URLClassLoader getClassLoader(){
        if(_classLoader == null) {
            File libDir = getLibDir();
            File[] children = libDir.listFiles(new ExtFilter(".jar"));
            if(children.length<2) {
                libDir=new File(libDir,"lib");
                setLibDir(libDir);
                children = libDir.listFiles(new ExtFilter(".jar"));
            }
            
            URL[] urls = new URL[children.length];
            if(debug) System.out.println("Loading Jars");
            for(int i=0;i<children.length;i++){
                try {
                    urls[i]=children[i].toURI().toURL();
                    if(debug) System.out.println("- "+urls[i]);
                } catch (MalformedURLException e) {
                    e.printStackTrace();
                }
            }
            URLClassLoader cl = new URLClassLoader(urls,classLoader);
            _classLoader = cl;
        }
        return _classLoader;
    }
	
	public static String[] removeElement(String[] input, String deleteMe) {
		final List<String> list =  new ArrayList<String>();
		Collections.addAll(list, input);
		for(String item: input) {
	        if(item.startsWith(deleteMe)) {
	        	list.remove(item);
	        }
		}
		input = list.toArray(new String[list.size()]);
		return input;
	}
	
	public static String[] removeElementThenAdd(String[] input, String deleteMe, String[] addList) {
	    List<String> result = new LinkedList<String>();
	    for(int x =0; x < input.length; x++) {
	        if(input[x].startsWith(deleteMe)){
	            x++;
	        } else {
	            result.add(input[x]);
	        }
	    }

	    if(addList != null && addList.length > 0)
		    for(String item : addList)
		    		result.add(item);
	    
	    return result.toArray(input);
	}


	public static class ExtFilter implements FilenameFilter {
		private String ext;
		public ExtFilter(String extension) {
			ext = extension;
		}
		public boolean accept(File dir, String name) {
			return name.toLowerCase().endsWith(ext);
		}
	}
	
	public static class PrefixFilter implements FilenameFilter {
	    private String prefix;
	    public PrefixFilter(String prefix) {
	        this.prefix = prefix;
	    }
	    public boolean accept(File dir, String name) {
	        return name.toLowerCase().startsWith(prefix);
	    }
	}
	
	public static String arrayToList(String[] s, String separator) {  
        String result = "";
        if (s.length > 0) {
            result = s[0];
            for (int i = 1; i < s.length; i++) {
                result += separator + s[i];
            }
        }
        return result;
	}
	
	public static int listContains(ArrayList<String> argList, String text) {  
		for(String item : argList)
	        if(item.startsWith(text))
	            return argList.indexOf(item);
		return 0;
	}
	
	public static int listContainsNoCase(ArrayList<String> argList, String text) {  
	    for(String item : argList)
	        if(item.toLowerCase().startsWith(text.toLowerCase()))
	            return argList.indexOf(item);
	    return 0;
	}
	
	public static void listRemoveContaining(ArrayList<String> argList, String text) {
		for (Iterator<String> it = argList.iterator(); it.hasNext();) {
			String str = it.next();
			if (str.startsWith(text)) {
				it.remove();
			}
		}
	}
	
	private static Map<String, String> toMap(String[] args) {
		int index;
		Map<String, String> config=new HashMap<String, String>();
		String raw,key,value;
		if(args!=null)for(int i=0;i<args.length;i++){
			raw=args[i].trim();
			if(raw.length() == 0) continue;
			if(raw.startsWith("-"))raw=raw.substring(1).trim();
			index=raw.indexOf('=');
			if(index==-1) {
				key=raw;
				value="";
			}
			else {
				key=raw.substring(0,index).trim();
				value=raw.substring(index+1).trim();
			}
			config.put(key.toLowerCase(), value);
		}
		return config;
	}

	public static String getPathRoot(String string) {
		return string.replaceAll("^([^\\\\//]*?[\\\\//]).*?$", "$1");
	}

    private static String getCurrentDir() {
        return System.getProperty("user.dir");
    }
    
    private static void setCLI_HOME(File value) {
        CLI_HOME = value;
    }
    
    private static File getCLI_HOME() {
        return CLI_HOME;
    }
    
    private static File getCLI_HOME(ArrayList<String> cliArguments, Properties props, String[] arguments, Map<String, String> config) {
        File cli_home = null;
        String name = getName();
        String home = name+"_home";
        String homeLower = (name+"_home").toLowerCase();
        String homeUpper = (name+"_home").toUpperCase();
        if(getCLI_HOME() == null) {
            Map<String, String> env = System.getenv();
            log.debug("home: checking for command line argument "+homeLower);
            if (config.get(homeLower) != null) {
                cli_home = new File(config.get(homeLower));
                arguments = removeElement(arguments,"-"+homeLower);
                listRemoveContaining(cliArguments,"-"+homeLower);
            }
            if(cli_home == null){
                log.debug("home: checking for environment variable");
                if (env.get(home) != null) {
                    cli_home = new File(env.get(home));
                } else if (env.get(homeLower) != null) {
                    cli_home = new File(env.get(homeLower));
                } else if (env.get(homeUpper) != null) {
                    cli_home = new File(env.get(homeUpper));
                }
            }
            if(cli_home == null){
                log.debug("home: checking for system property");
                if (System.getProperty(home) != null) {
                    cli_home = new File(System.getProperty(home));
                } else if (System.getProperty(homeLower) != null) {
                    cli_home = new File(System.getProperty(homeLower));
                } else if (System.getProperty(homeUpper) != null) {
                    cli_home = new File(System.getProperty(homeUpper));
                }
            }
            if(cli_home == null){
                log.debug("home: checking cli.properties");
                if (props.getProperty(home) != null) {
                    cli_home = new File(props.getProperty(home));
                } else if (props.getProperty(homeLower) != null) {
                    cli_home = new File(props.getProperty(homeLower));
                } else if (props.getProperty(homeUpper) != null) {
                    cli_home = new File(props.getProperty(homeUpper));
                }
            }
            if(cli_home == null){
                log.debug("home: using default");
                String userHome = System.getProperty("user.home");
                if(userHome != null) {
                    cli_home = new File(userHome + "/."+name+"/");
                } else {
                    cli_home = new File(LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath()).getParentFile();
                }
            }
        }
        setCLI_HOME(cli_home);
        log.debug("home: "+cli_home.getAbsolutePath());
        return cli_home;
    }

    private static Boolean isBackground() {
        return isBackground;
    }
    
    private static void setBackground(Boolean value) {
        isBackground = value;
    }
    
    private static void setWebRoot(File value) {
        webRoot = value;
    }
    
    private static File getWebRoot() {
        return webRoot;
    }
    
    private static void setLibDir(File value) {
        libDirectory = value;
    }
    
    private static File getLibDir() {
        return libDirectory;
    }
    
    private static void setRailoConfigServerDir(File value) {
        railoConfigServerDirectory = value;
    }
    
    private static File getRailoConfigServerDir() {
        return railoConfigServerDirectory;
    }
    
    private static void setRailoConfigWebDir(File value) {
        railoConfigWebDirectory = value;
    }
    
    private static File getRailoConfigWebDir() {
        return railoConfigWebDirectory;
    }
    
    private static void setName(String value) {
        name = value;
    }
    
    private static String getName() {
        return name;
    }
    
    private static void setShellPath(String value) {
        shellPath = value;
    }
    
    private static String getShellPath() {
        return shellPath;
    }
    
    private static class log {
        public static void debug(String message){
            if(debug){
                System.out.println(message.replace("/n",CR));
            }
        }
        public static void warn(String message){
            System.out.println(message.replace("/n",CR));
        }
        public static void error(String message){
            System.err.println(message.replace("/n",CR));
        }
    }
    
	
}
