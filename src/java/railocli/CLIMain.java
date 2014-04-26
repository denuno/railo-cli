package railocli;

import java.io.File;
import java.io.IOException;
import java.io.ByteArrayOutputStream;
import java.io.PrintStream;
import java.util.HashMap;
import java.util.Map;

import java.awt.Image;
import javax.imageio.ImageIO;

import java.lang.reflect.Method;

import javax.servlet.ServletException;
import javax.servlet.jsp.JspException;

import railo.loader.engine.CFMLEngine;
import railo.loader.engine.CFMLEngineFactory;
import railo.loader.util.Util;

public class CLIMain {
/**
 * Config
 * 
 * webroot - webroot directory
 * servlet-name - name of the servlet (default:CFMLServlet)
 * server-name - server name (default:localhost)
 * uri - host/scriptname/query
 * cookie - cookies (same pattern as query string)
 * form - form (same pattern as query string)
 */
	
	
	/**
	 * @param args
	 * @throws JspException 
	 */
	public static void main(String[] args) throws ServletException, IOException, JspException {
		Map<String,String> config=toMap(args);
		Boolean debug = false;
		
		File currentDir = new File(CLIMain.class.getProtectionDomain().getCodeSource().getLocation().getPath()).getParentFile();
		File libDir=new File(currentDir.getPath()).getCanonicalFile();
		
		// libs dir
		String strLibs=config.get("libs");
		if(strLibs != null && strLibs.length() != 0) {
			libDir=new File(strLibs);
		}

		// debug
		String strDebug=config.get("debug");
		if(!Util.isEmpty(strDebug,true)) debug = true;
		
		if(debug) System.out.println("libDir dir" + libDir.getPath());

		// webroot
		String strRoot=config.get("webroot");
		File root;
		if(Util.isEmpty(strRoot,true)) {
			//root=new File("./").getCanonicalFile();
			root=new File("/").getCanonicalFile();
		} else {
			root=new File(strRoot);
		}
		config.put("webroot",root.getPath());
		//root.mkdirs();

		String strServerroot=config.get("server-config");
		File serverRoot;
		if(Util.isEmpty(strServerroot,true)) {
			serverRoot=new File(libDir.getParentFile(),"server");
			//serverRoot=libDir;
		} else {
			serverRoot=new File(strServerroot);
		}
		config.put("server-config", serverRoot.getAbsolutePath());
		//serverRoot.mkdirs();
		
		String strWebroot=config.get("web-config");
		File webConfig;
		if(Util.isEmpty(strWebroot,true)) {
			webConfig=new File(libDir.getParentFile(),"server/railo-web");
		} else {
			webConfig=new File(strWebroot);
		}
		config.put("web-config", webConfig.getAbsolutePath());
		//webRoot.mkdirs();

		// if no uri arg, use first non -dashed arg
		String strUri=config.get("uri");
		if(strUri == null || strUri.length() == 0) {
			String raw;
			if(args!=null)for(int i=0;i<args.length;i++){
				raw=args[i].trim();
				if(raw.length() == 0) continue;
				if(!raw.startsWith("-")) {
					raw = new File(raw).getCanonicalFile().getPath();
					config.put("uri",raw);
					break;
				}
			}
		}
		// fix for windows. remove drive letter.  TODO: find out why this is needed
		config.put("uri", new File(config.get("uri")).toURI().toURL().toExternalForm().replaceAll("file:/(\\w:)", "file://$1"));
		// hack to prevent . being picked up as the system path (jacob.x.dll)
		if(System.getProperty("java.library.path") == null) {
			System.setProperty("java.library.path",libDir.getPath());
		} else {
			System.setProperty("java.library.path",libDir.getPath() + ":" + System.getProperty("java.library.path"));
		}
        String osName = System.getProperties().getProperty("os.name");
        if(osName != null && osName.startsWith("Mac OS X"))
        {   
            try{
            	Image dockIcon = ImageIO.read(CLIMain.class.getResource("/railocli/railo.png"));
            	Class<?> appClass = Class.forName("com.apple.eawt.Application");
            	Method getAppMethod = appClass.getMethod("getApplication");
            	Object appInstance = getAppMethod.invoke(null);
            	Method dockMethod = appInstance.getClass().getMethod("setDockIconImage", java.awt.Image.class);
            	dockMethod.invoke(appInstance, dockIcon);		
            }
            catch(Exception e) { /* e.printStackTrace(); */ }
        }

		if(debug) {
			System.out.println("Config:" + config);
		}
		// servletNane
		String servletName=config.get("servlet-name");
		if(Util.isEmpty(servletName,true))servletName="CFMLServlet";
		
		Map<String,Object> attributes=new HashMap<String, Object>();
		Map<String, String> initParameters=new HashMap<String, String>();
		initParameters.put("railo-server-directory", serverRoot.getAbsolutePath());
		initParameters.put("configuration", webConfig.getAbsolutePath());
		
		CLIContext servletContext = new CLIContext(root, webConfig, attributes, initParameters, 1, 0);
		ServletConfigImpl servletConfig = new ServletConfigImpl(servletContext, servletName);
		PrintStream printStream = new PrintStream(new ByteArrayOutputStream());
		PrintStream origOut = System.out;
		if(!debug) {
			System.setOut(printStream);
		}
		CFMLEngine engine = null;
		try{
			engine = CFMLEngineFactory.getInstance(servletConfig);
		} catch (Exception e) {
			e.printStackTrace();
		} finally {
			System.setOut(origOut);
		}
		printStream.close();

		engine.cli(config,servletConfig);

	}
// java railo-cli.jar -config=.../railo-web.xml.cfm -uri=/susi/index.cfm?test=1 -form=name=susi -cgi=user_agent=urs -output=.../test.txt ...

	private static Map<String, String> toMap(String[] args) {
		int index;
		Map<String, String> config=new HashMap<String, String>();
		String raw,key,value;
		if(args!=null)for(int i=0;i<args.length;i++){
			raw=args[i].trim();
			if(Util.isEmpty(raw, true)) continue;
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
