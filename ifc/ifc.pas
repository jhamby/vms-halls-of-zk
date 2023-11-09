[inherit('lib$:typedef',
	 'starlet',
	 'pascal$cli_routines',
	 'pascal$lib_routines',
	 'lib$:ifc$msg_def',
	 'lib$:ifc$message_def',
	 'lib$:ifc$room_def',
	 'lib$:ifc$object_def')]

program ifc(input, output);

var	command_table : [external(ifc$command_table)] unsigned;

[asynchronous] function condition_handler(
	var signal : $signal_arg_vector;
	var mech : $mech_arg_vector) : unsigned;

begin
	if (signal[1]<>ss$_unwind) then
	  begin
		signal[0]:=signal[0]-2;
		$putmsg(signal);
	  end;

	if (uand(signal[1],7)=4) then $unwind
	else
		condition_handler:=ss$_continue;
end;

procedure get_filespec(
	file_type : varying[$u1] of char;
	var source_filename : varying[$u2] of char;
	var macro_filename : varying[$u3] of char;
	var def_filename : varying[$u4] of char);

var	temp_filename : varying[80] of char;
	return, context : unsigned;
begin
	cli$get_value('FILENAME', %descr temp_filename);
	context:=0;
	lib$find_file(temp_filename, %descr source_filename, context, file_type);
	lib$find_file_end(context);

	temp_filename.length:=0;
	return:=cli$present('MACRO');
	if (odd(return)) then cli$get_value('MACRO', %descr temp_filename);

	context:=0;
	lib$find_file(temp_filename, %descr macro_filename,
			context, '.MAR', source_filename);
	lib$find_file_end(context);

	macro_filename.length:=index(macro_filename,';')-1;

	temp_filename.length:=0;
	return:=cli$present('DEFINITIONS');
	if (odd(return)) then cli$get_value('DEFINITIONS', %descr temp_filename);

	context:=0;
	lib$find_file(temp_filename, %descr def_filename,
			context, '.PAS', source_filename);
	lib$find_file_end(context);

	def_filename.length:=index(def_filename,';')-1;
end;

[global] function ifc$compile_objects_main : unsigned;
var	source_filename,
	macro_filename,
	def_filename : varying[80] of char;
begin
	establish(condition_handler);

	get_filespec('.OBJECT',source_filename,macro_filename,def_filename);

	$compile_objects(source_filename,macro_filename, def_filename);

	ifc$compile_objects_main:=1;
end;

[global] function ifc$compile_messages_main : unsigned;
var	source_filename,
	object_filename,
	def_filename : varying[80] of char;
begin
	establish(condition_handler);

	get_filespec('.MESSAGE',source_filename,object_filename,def_filename);

	$compile_messages(source_filename, object_filename, def_filename);

	ifc$compile_messages_main:=1;
end;

[global] function ifc$compile_rooms_main : unsigned;
var	source_filename,
	object_filename,
	def_filename : varying[80] of char;
begin
	establish(condition_handler);

	get_filespec('.ROOM',source_filename,object_filename,def_filename);

	$compile_rooms(source_filename, object_filename, def_filename);

	ifc$compile_rooms_main:=1;
end;

[global] function ifc$help : unsigned;
begin
	lib$signal(ifc$_nyi);
	ifc$help:=1;
end;

[global] function ifc$exit : unsigned;
begin
	ifc$exit:=rms$_eof;
end;

procedure main;
var	return : unsigned;
	command : varying[80] of char;
begin
	return:=lib$get_foreign(%descr command);
	if (command.length<>0) then
	  begin
		return:=cli$dcl_parse(command, command_table);
		if (odd(return)) then cli$dispatch;
	  end
	else
	  begin
		return:=1;
		while (return<>rms$_eof) do
		  begin
			return:=cli$dcl_parse(,command_table, %immed lib$get_input,
					%immed lib$get_input, 'ifc> ');
			if (odd(return)) then return:=cli$dispatch;
		  end;
	  end;
end;

begin
	main;
end.
