package cliloader;

import java.io.File;
import java.io.FileOutputStream;
import java.io.BufferedInputStream;
import java.io.IOException;
import java.io.FilenameFilter;
import java.lang.reflect.Method;
import java.net.URL;
import java.net.URLClassLoader;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Map;
import java.util.LinkedList;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Properties;
import java.util.jar.JarEntry;
import java.util.jar.JarInputStream;

public class LoaderCLIMain {

	private static String LIB_ZIP_PATH = "libs.zip";
	private static String CFML_ZIP_PATH = "cfml.zip";
	private static final int KB = 1024;
	private static ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
	private static Boolean debug = false;

	public static void main(String[] args) throws Throwable {
		Properties props = new Properties();
		try {
	        props.load(classLoader.getSystemResourceAsStream("cliloader/cli.properties"));
	    } catch (IOException e) { e.printStackTrace(); }
		String name = props.getProperty("name") != null ? props.getProperty("name") : "railo";
		String NAME = name.toUpperCase();
		String version = props.getProperty("version") != null ? props.getProperty("version") : "0.0.0.0";
		Map<String,String> config=toMap(args);
		Boolean updateLibs = false;
		Boolean startServer = false;
		Boolean background = false;
		File cli_home;
		Map<String, String> env = System.getenv();
		if (config.get(name+"_home") != null) {
			cli_home = new File(config.get(name+"_home"));
			args = removeElement(args,"-"+name+"_home");
		} else if (System.getProperty(NAME+"_HOME") != null) {
			cli_home = new File(System.getProperty(NAME+"_HOME"));
		} else if (env.get(NAME+"_HOME") != null) {
			cli_home = new File(env.get(NAME+"_HOME"));
		} else {
			String userHome = System.getProperty("user.home");
			if(userHome != null) {
				cli_home = new File(userHome + "/."+name+"/");
			} else {
				cli_home = new File(LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath()).getParentFile();
			}
		}
		if(!cli_home.exists()) {
			System.out.println("Configuring "+name+" home: "+ cli_home + " (change with -"+name+"_home=/path/to/dir)");
			cli_home.mkdir();
		}
		//System.out.println(home_dir.getPath());
		File libDir=new File(cli_home,"lib").getCanonicalFile();
		
		// debug
		if(config.get("debug") != null) {
			debug = true;
			System.out.println("Using configuration in "+ cli_home + " (change with -"+name+"_home=/path/to/dir)");
		}
		// update/overwrite libs
		if(config.get("update") != null) {
			System.out.println("updating "+name+" home");
			updateLibs = true;
			args = removeElement(args,"-update");
		}
		// background
		if(config.get("background") != null) {
			background = true;
			args = removeElement(args,"-background");
		}
		
		// default to running the shell
		if(args.length == 0) {
			config.put("shell","true");			
		}
		if(!updateLibs && (config.get("?") != null || config.get("help") != null)) {
			System.out.println(props.get("usage").toString().replace("/n",System.getProperty("line.separator").toString()));
			Thread.sleep(1000);
			System.exit(0);
		}
		
		// railo libs dir
		String strLibs=config.get("lib");
		if(strLibs != null && strLibs.length() != 0) {
			libDir=new File(strLibs);
			args = removeElementThenAdd(args,"-lib=","");
		}

		String strStart=config.get("server");
		if(strStart != null) {
			startServer=true;
		}

		File webRoot;
		if(config.get("webroot") != null) {
			webRoot = new File(config.get("webroot")).getCanonicalFile();
		} else {
			webRoot = new File("./").getCanonicalFile();
		}

		if(debug) System.out.println("lib dir: " + libDir);

		if (!libDir.exists() || libDir.listFiles(new ExtFilter()).length < 2 
				|| updateLibs) {
			System.out.println("Library path: " + libDir);
			System.out.println("Initializing libraries -- this will only happen once, and takes a few seconds...");
			unzipInteralZip(LIB_ZIP_PATH,libDir);
			unzipInteralZip(CFML_ZIP_PATH,new File(cli_home.getPath()+"/cfml"));
			System.out.println("");
			System.out.println("Libraries initialized");
			if(updateLibs && args.length == 0) {
				System.out.println("updated! ctrl-c now or wait a few seconds for exit..");
				System.exit(0);
			}
		}
		
        File[] children = libDir.listFiles(new ExtFilter());
        if(children.length<2) {
        	libDir=new File(libDir,"lib");
        	 children = libDir.listFiles(new ExtFilter());
        }
        
        URL[] urls = new URL[children.length];
        if(debug) System.out.println("Loading Jars");
        for(int i=0;i<children.length;i++){
        	urls[i]=children[i].toURI().toURL();
        	if(debug) System.out.println("- "+urls[i]);
        }
        //URLClassLoader cl = new URLClassLoader(urls,ClassLoader.getSystemClassLoader());
        //URLClassLoader cl = new URLClassLoader(urls,null);
        URLClassLoader cl = new URLClassLoader(urls,classLoader);
		//Thread.currentThread().setContextClassLoader(cl);
        Class cli;
        if(!startServer) {
    		String SHELL_CFM = props.getProperty("shell") != null ? props.getProperty("shell") : "/cfml/cli/shell.cfm";
        	if(debug) System.out.println("Running in CLI mode");
    		if(config.get("repl") != null || config.get("shell") != null) {
        		args = removeElementThenAdd(args,"-uri","-uri="+ cli_home + SHELL_CFM);
    		}
	        cli = cl.loadClass("railocli.CLIMain");
        } 
        else {
        	if(debug) System.out.println("Running in server mode");
	        cli = cl.loadClass("runwar.Start");
			String path = LoaderCLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath();
			//System.out.println("yum from:"+path);
			String decodedPath = java.net.URLDecoder.decode(path, "UTF-8");
			decodedPath = new File(decodedPath).getPath();

    		//args = removeElementThenAdd(args,"-server","-war "+webRoot.getPath()+" --background false --logdir " + libDir.getParent());
    		String argstr;
    		if(background) {
    			argstr="-war "+webRoot.getPath()+" --background true --jar \""+decodedPath.replace('\\','/')+"\" --libdir \"" + libDir.getPath() +"\"";
    		} else {
    			argstr="-war "+webRoot.getPath()+" --background false";
    		}
    		args = removeElementThenAdd(args,"-server",argstr);
        	if(debug) System.out.println("Args: " + java.util.Arrays.toString(args));
        } 
        Method main = cli.getMethod("main",new Class[]{String[].class});
		try{
        	main.invoke(null, new Object[]{args});
		} catch (Exception e) {
			e.getCause().printStackTrace();
		}
	}
	
	public static void unzipInteralZip(String resourcePath, File libDir) {
		if(debug) System.out.println("Extracting " + resourcePath);
		libDir.mkdir();
		URL resource = classLoader.getResource(resourcePath);
		if (resource == null) {
			System.err.println("Could not find the " + resourcePath + " on classpath!");
			System.exit(1);
		}
		try {

			BufferedInputStream bis = new BufferedInputStream(resource.openStream());
			JarInputStream jis = new JarInputStream(bis);
			JarEntry je = null;

			while ((je = jis.getNextJarEntry()) != null) {
				java.io.File f = new java.io.File(libDir.toString() + java.io.File.separator + je.getName());
				if (je.isDirectory()) {
					f.mkdir();
					continue;
				}
				File parentDir = new File(f.getParent());
				if (!parentDir.exists()) {
					parentDir.mkdir();
				}
				writeStreamTo(jis, new FileOutputStream(f), 8 * KB);
				if(f.getPath().endsWith("pack.gz")) {
					Util.unpack(f);
					f.delete();
				}
				System.out.print(".");
			}
			bis.close();
		} catch (Exception exc) {
			exc.printStackTrace();
		}
		
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
	
	public static String[] removeElementThenAdd(String[] input, String deleteMe, String addList) {
	    List<String> result = new LinkedList<String>();
	    for(String item : input)
	        if(!item.startsWith(deleteMe))
	            result.add(item);

	    for(String item : addList.split(" "))
	    		result.add(item);
	    
	    return result.toArray(input);
	}


	public static class ExtFilter implements FilenameFilter {
		
		private String ext=".jar";
		public boolean accept(File dir, String name) {
			return name.toLowerCase().endsWith(ext);
		}

	}

	public static int writeStreamTo(final InputStream input, final OutputStream output, int bufferSize)
			throws IOException {
		int available = Math.min(input.available(), 256 * KB);
		byte[] buffer = new byte[Math.max(bufferSize, available)];
		int answer = 0;
		int count = input.read(buffer);
		while (count >= 0) {
			output.write(buffer, 0, count);
			answer += count;
			count = input.read(buffer);
		}
		return answer;
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
}
