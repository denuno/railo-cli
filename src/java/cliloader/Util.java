package cliloader;

import java.io.*;
import java.net.URL;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Timer;
import java.util.TimerTask;
import java.util.jar.*;
import java.util.zip.GZIPInputStream;

import cliloader.LoaderCLIMain.ExtFilter;
import cliloader.LoaderCLIMain.PrefixFilter;

public class Util {

	private static final int KB = 1024;

	public static void unzipInteralZip(ClassLoader classLoader, String resourcePath, File libDir, boolean debug) {
		if (debug)
			System.out.println("Extracting " + resourcePath);
		libDir.mkdir();
		URL resource = classLoader.getResource(resourcePath);
		if (resource == null) {
			System.err.println("Could not find the " + resourcePath + " on classpath!");
			System.exit(1);
		}
		class PrintDot extends TimerTask {
			public void run() {
				System.out.print(".");
			}
		}
		Timer timer = new Timer();
		PrintDot task = new PrintDot();
		timer.schedule(task, 0, 2000);

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
				FileOutputStream fileOutStream = new FileOutputStream(f);
				writeStreamTo(jis, fileOutStream, 8 * KB);
				if (f.getPath().endsWith("pack.gz")) {
					unpack(f);
					fileOutStream.close();
					f.delete();
				}
			}

		} catch (Exception exc) {
			task.cancel();
			exc.printStackTrace();
		}
		task.cancel();

	}
	
	public static void cleanUpUnpacked(File libDir) {
        if(libDir.exists() && libDir.listFiles(new ExtFilter(".gz")).length > 0){
            for(File gz : libDir.listFiles(new ExtFilter(".gz"))) {
                try { gz.delete(); } catch (Exception e) {}
            }
        }
	}
	
	public static void removePreviousLibs(File libDir) {
		if(libDir.exists() && libDir.listFiles(new PrefixFilter("runwar")).length > 0){
			for(File previous : libDir.listFiles(new PrefixFilter("runwar"))) {
				try { previous.delete(); } catch (Exception e) {
					System.err.println("Could not delete previous lib: " + previous.getAbsolutePath());
				}
			}
		}
	}
	
	public static void copyInternalFile(ClassLoader classLoader, String resourcePath, File dest) {
		URL resource = classLoader.getResource(resourcePath);
		try {
			BufferedInputStream bis = new BufferedInputStream(resource.openStream());
			FileOutputStream output = new FileOutputStream(dest);
			writeStreamTo(bis, output, 8 * KB);
			output.close();
		} catch (FileNotFoundException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		} catch (IOException e) {
			// TODO Auto-generated catch block
			e.printStackTrace();
		}
        
	}

	public static void unpack(File inFile) {

		JarOutputStream out = null;
		InputStream in = null;
		String inName = inFile.getPath();
		String outName;

		if (inName.endsWith(".pack.gz")) {
			outName = inName.substring(0, inName.length() - 8);
		} else if (inName.endsWith(".pack")) {
			outName = inName.substring(0, inName.length() - 5);
		} else {
			outName = inName + ".unpacked";
		}
		try {
			Pack200.Unpacker unpacker = Pack200.newUnpacker();
			out = new JarOutputStream(new FileOutputStream(outName));
			in = new FileInputStream(inName);
			if (inName.endsWith(".gz"))
				in = new GZIPInputStream(in);
			unpacker.unpack(in, out);
		} catch (IOException ex) {
			ex.printStackTrace();
		} finally {
			if (in != null) {
				try { in.close();} catch (IOException ex) {
					System.err.println("Error closing file: " + ex.getMessage());
				}
			}
			if (out != null) {
				try { out.flush(); out.close(); } catch (IOException ex) {
					System.err.println("Error closing file: " + ex.getMessage());
				}
			}
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

	public static void copyFile(File source, File dest) throws IOException {
	  FileInputStream fi = new FileInputStream(source);
	  FileChannel fic = fi.getChannel();
	  MappedByteBuffer mbuf = fic.map(
	    FileChannel.MapMode.READ_ONLY, 0, source.length());
	  fic.close();
	  fi.close();
	  FileOutputStream fo = new FileOutputStream(dest);
	  FileChannel foc = fo.getChannel();
	  foc.write(mbuf);
	  foc.close();
	  fo.close();
	}

    static String getResourceAsString(String path) {
        InputStream is = null;
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        PrintStream outPrint = new PrintStream(out);
        try {
            is = Util.class.getClassLoader().getResourceAsStream(path);
            int content;
            while ((content = is.read()) != -1) {
                // convert to char and display it
                outPrint.print((char) content);
            }
        } catch (IOException e) {
            e.printStackTrace();
        } finally {
            try {
                if (is != null)
                    is.close();
                if (outPrint != null)
                    outPrint.close();
            } catch (IOException ex) {
                ex.printStackTrace();
            }
        }
        return out.toString();
    }
    
    static String readFile(String path) throws IOException {
        return readFile(path, StandardCharsets.UTF_8);
    }

    static String readFile(String path, Charset encoding) throws IOException {
        byte[] encoded = Files.readAllBytes(Paths.get(path));
        return new String(encoded, encoding);
    }

    public static void ensureJavaVersion() {
        Class<?> nio;
        try{
            nio = Util.class.getClassLoader().loadClass("java.nio.charset.StandardCharsets");
            if(nio == null) {
                System.out.println("Could not load NIO!  Are we running on Java 7 or greater?  Sorry, exiting...");                
                System.exit(1);
            }
        } catch (java.lang.ClassNotFoundException e) {
            System.out.println("Could not load NIO!  Are we running on Java 7 or greater?  Sorry, exiting...");
            System.exit(1);
        }
    }
    
}
