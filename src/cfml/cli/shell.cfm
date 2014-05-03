<cfsilent>
<cfset _shellprops = { version:'0.1' } >
<cfsetting requesttimeout="9999" />
<cfsavecontent variable="_shellprops.help">Welcome!
Type "help" for help, or "help [namespace|command] [command]" to be more specific.
</cfsavecontent>
<cfscript>
	systemOutput(_shellprops.help);
	shell = new Shell();
	while (shell.run()) {
		systemOutput("Reloading shell.");
		SystemCacheClear("all");
		shell = javacast("null","");
		shell = new Shell();
	}
	system = createObject("java","java.lang.System");
    system.runFinalization();
    system.gc();
</cfscript>
</cfsilent>
