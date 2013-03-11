component name="TestShell" extends="mxunit.framework.TestCase" {

	public void function testCommandHandler()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var bain = createObject("java","java.io.ByteArrayInputStream").init("ls#chr(10)#".getBytes());
    	var printWriter = createObject("java","java.io.PrintWriter").init(baos);
		var shell = new cfml.cli.Shell(bain,printWriter);
		commandHandler = new cfml.cli.CommandHandler(shell);
		commandHandler.loadCommands(new cfml.cli.Commands(shell));
		commandHandler.runCommand("ls");
		debug(baos.toString());

	}

	public void function testShell()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var printWriter = createObject("java","java.io.PrintWriter").init(baos);
    	var n = chr(10);
    	var line = "ls" &n& "q" & n;
    	var inStream = createObject("java","java.io.ByteArrayInputStream").init(line.getBytes());
		var shell = new cfml.cli.Shell(inStream,printWriter);
		shell.run();
		debug(baos.toString());

	}

	public void function testShellComplete()  {
    	var baos = createObject("java","java.io.ByteArrayOutputStream").init();
    	var printWriter = createObject("java","java.io.PrintWriter").init(baos);
    	var t = chr(9);
    	var n = chr(10);
		var shell = new cfml.cli.Shell(printWriter=printWriter);


		shell.run("hel#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		debug(wee);
		assertTrue(find("HELP",wee));
		baos.reset();

		shell.run("ls #t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		debug(wee);
		baos.reset();

		shell.run("ls#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		debug(wee);
		baos.reset();

		shell.run("test#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		debug(wee);
		baos.reset();

		shell.run("testplug ro#t# #n#");
		wee = replace(baos.toString(),chr(0027),"","all");
		debug(wee);
		baos.reset();

		shell.run("testplug o#t#");
		wee = replace(baos.toString(),chr(0027),"","all");
		debug(wee);
		baos.reset();

	}

}