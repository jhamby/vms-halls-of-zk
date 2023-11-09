[inherit('lib$:typedef',
	 'starlet',
	 'pascal$lib_routines',
	 'pascal$str_routines',
	 'pascal$smg_routines')]
module ifc$rtl_screen;

const	number_trans = 4;

type	$trans_record = record
				pattern : varying[10] of char;
				replacement : varying[10] of char;
			end;
	$trans_array = array[1..number_trans] of $trans_record;
	$char_array = packed array[1..132] of char;

	$pointer = [unsafe, long] packed record
			case integer of
			1 : (address : unsigned);
			2 : (byte_ptr : ^$ubyte);
			3 : (word_ptr : ^$uword);
			4 : (long_ptr : ^unsigned);
			5 : (char_ptr : ^$char_array);
		   end;

var	screen,				(* pasteboard *)
	status_line,			(* virtual display *)
	main_display,			(* virtual display *)
	more_indicator,			(* virtual display *)
	terminal,			(* virtual keyboard *)
	key_table:			(* terminal key definition table *)
		[volatile, static] unsigned;
	line_count:
		[volatile, static] integer := 0;

[global] function ifc$init_screen(
	key_logical_name : varying[$u1] of char;
	[unbound, asynchronous] procedure ast_routine;
	ast_argument : [unsafe] unsigned) : unsigned;

var	return : unsigned;
	item_list : $item_list;
	version : packed array[1..8] of char;
begin
	establish(lib$sig_to_ret);

	return:=smg$create_pasteboard(screen);
	if (not odd(return)) then lib$signal(return);

	return:=smg$create_virtual_keyboard(terminal);
	if (not odd(return)) then lib$signal(return);

	return:=smg$create_key_table(key_table);
	if (not odd(return)) then lib$signal(return);

	return:=smg$load_key_defs(key_table, key_logical_name, '.COM');
	if ( (not odd(return)) and (return<>rms$_fnf) ) then
		lib$signal(return);

	return:=smg$create_virtual_display(1,80,status_line,,smg$m_reverse);
	if (not odd(return)) then lib$signal(return);

	return:=smg$create_virtual_display(23,80,main_display);
	if (not odd(return)) then lib$signal(return);

	return:=smg$create_virtual_display(1,9,more_indicator,,smg$m_reverse);
	if (not odd(return)) then lib$signal(return);

	return:=smg$set_broadcast_trapping(screen, %immed ast_routine,
					ast_argument);
	if (not odd(return)) then lib$signal(return);

	return:=smg$put_chars(status_line,'Score:',1,50);
	if (not odd(return)) then lib$signal(return);
	return:=smg$put_chars(status_line,'Moves:',1,65);
	if (not odd(return)) then lib$signal(return);
	return:=smg$put_chars(more_indicator,'[More...]',1,1);
	if (not odd(return)) then lib$signal(return);

	return:=smg$paste_virtual_display(status_line,screen,1,1);
	if (not odd(return)) then lib$signal(return);

	return:=smg$paste_virtual_display(main_display,screen,2,1);
	if (not odd(return)) then lib$signal(return);

	(* KLUDGE FOR V40,V41 SMG BUGS BEGINS HERE *)
(*
	item_list[1].buffer_length:=8;
	item_list[1].item_code:=syi$_version;
	item_list[1].buffer_address:=iaddress(version);
	item_list[1].return_length_address:=0;
	item_list[2].buffer_length:=0;
	item_list[2].item_code:=0;

	return:=$getsyiw(,,,item_list);
	if (not odd(return)) then lib$signal(return);

	if ( (version[2]='4') and
		( (version[4]='0') or (version[4]='1') ) ) then
	  begin
		return:=$set_cursor_abs(main_display, 23, 1);
		if (not odd(return)) then lib$signal(return);
	  end;
*)

	ifc$init_screen:=ss$_normal;
end;

[global] function ifc$finish_screen : unsigned;
var	return : unsigned;
begin
	establish(lib$sig_to_ret);

	return:=smg$set_cursor_abs(main_display, 23, 1);
	if (not odd(return)) then lib$signal(return);

	return:=smg$delete_virtual_keyboard(terminal);
	if (not odd(return)) then lib$signal(return);

	return:=smg$delete_pasteboard(screen, 0);
	if (not odd(return)) then lib$signal(return);

	ifc$finish_screen:=ss$_normal;
end;

[global] function ifc$get_string(
	var string : varying[$u1] of char;
	prompt : varying[$u2] of char) : unsigned;
var	return : unsigned;
begin
	ifc$get_string:=smg$read_string(terminal, %descr string, prompt,,,,,,,
					main_display);
	line_count:=line_count + 1;
end;

[global] function ifc$get_composed_line(
	var string : varying[$u1] of char;
	prompt : varying[$u2] of char) : unsigned;

var	return : unsigned;
begin
	line_count:=1;
	return:=smg$read_composed_line(terminal, key_table,
			%descr string, prompt,, main_display);
	ifc$get_composed_line:=return;
end;

[asynchronous, global] function put_scroll_dx(
	column_number : (* [truncate] *) integer;
	var string : (* [truncate] *) varying[$u2] of char;
	new_attributes : (* [truncate] *) unsigned) : unsigned;

var	return : unsigned;
	attributes : unsigned;
	buf : varying[10] of char;
	temp : varying[132] of char;
begin
	if (line_count=23) then
	  begin
		line_count:=0;

		return:=smg$paste_virtual_display(more_indicator, screen, 24, 1);
		if (not odd(return)) then lib$signal(return);

		return:=smg$read_string(terminal, %descr buf,, 1, io$m_noecho);
		if (not odd(return)) then lib$signal(return);

		return:=smg$unpaste_virtual_display(more_indicator, screen);
		if (not odd(return)) then lib$signal(return);
	  end;
	line_count:=line_count + 1;

	attributes:=0;
	(* if (present(new_attributes)) then *) attributes:=new_attributes;

	(* if (not present(column_number)) then
		return:=$put_with_scroll(main_display)
	else *)
	if (column_number=1) then
		return:=smg$put_with_scroll(main_display,%descr string,,attributes,,1)
	else
	  begin
		temp := pad('', ' ', column_number-1) + string;
		return:=smg$put_with_scroll(main_display, temp,, attributes,,1)
	  end;

	put_scroll_dx:=return;
end;

procedure convert_n_s(
	score : integer;
	var string : varying[$u1] of char);
var	p : integer;
begin
	string:='  0'; p:=3;
	while ( (p>0) and (score>0) ) do
	  begin
		string[p]:=chr((score mod 10)+48);
		score:=score div 10;
		p:=p-1;
	  end;
end;

[global] function ifc$update_status_numbers(
	var score : integer;
	var moves : integer) : unsigned;

var	return : unsigned;
	string : varying[3] of char;
begin
	return:=smg$begin_display_update(status_line);
	if (not odd(return)) then lib$signal(return);

	convert_n_s(score, string);
	return:=smg$put_chars(status_line, string, 1, 57);
	if (not odd(return)) then lib$signal(return);

	convert_n_s(moves, string);
	return:=smg$put_chars(status_line, string, 1, 72);
	if (not odd(return)) then lib$signal(return);

	return:=smg$end_display_update(status_line);
	if (not odd(return)) then lib$signal(return);

	ifc$update_status_numbers:=ss$_normal;
end;

[global] function ifc$update_status_room(
	var string : varying[$u1] of char) : unsigned;

var	return : unsigned;
begin
	return:=smg$begin_display_update(status_line);
	if (not odd(return)) then lib$signal(return);

	return:=smg$erase_chars(status_line, 31, 1, 1);
	if (not odd(return)) then lib$signal(return);

	return:=smg$put_chars(status_line, string, 1, 1);
	if (not odd(return)) then lib$signal(return);

	return:=smg$end_display_update(status_line);
	if (not odd(return)) then lib$signal(return);

	ifc$update_status_room:=ss$_normal;
end;

[asynchronous] procedure correct_English(
	var string : [volatile] varying[$u1] of char);

var	lowered : boolean;
	p, i : integer;
	trans : [static] $trans_array :=
		( ('the self', 'you'),
		  ('you is', 'you are'),
		  ('you does', 'you do'),
		  ('s is', 's are') );
begin
	if (string[1]>='A') and (string[1]<='Z') then
	  begin
		string[1]:=chr(ord(string[1])+32); lowered:=true
	  end
	else	lowered:=false;

	for i:=1 to number_trans do
	  begin
		p:=index(string, trans[i].pattern);
		if (p<>0) then
			str$replace(%descr string, string, p,
				p + trans[i].pattern.length - 1,
				trans[i].replacement);
	  end;

	if ( (string[1]>='a') and (string[1]<='z') and (lowered)) then
		string[1]:=chr(ord(string[1])-32);
end;

[asynchronous] procedure write_message(
	column : integer;
	message_ptr : $pointer;
	fao_count : integer;
	fao_block : [volatile] array[$l4..$u4:integer] of integer);

var	attributes, return : unsigned;
	line_fao_count : integer;
	fao_buffer : varying[132] of char value '';
	dsc_buffer : varying[132] of char;
	desc_len : integer;
	i, fao_index : integer value 1;
begin
	if (message_ptr.address=0) then
		put_scroll_dx(1, fao_buffer, 0)
	else
	while (message_ptr.word_ptr^<>0) do
	  begin
		desc_len:=message_ptr.byte_ptr^;

		message_ptr.address:=message_ptr.address + 1;
		line_fao_count:=message_ptr.byte_ptr^;

		message_ptr.address:=message_ptr.address + 1;
		attributes:=message_ptr.byte_ptr^;

		message_ptr.address:=message_ptr.address + 1;
		dsc_buffer := message_ptr.char_ptr^[1..desc_len];

		message_ptr.address:=message_ptr.address + desc_len;
		if (line_fao_count=0) then
		  begin
			return:=put_scroll_dx(column, dsc_buffer, attributes);
			if (not odd(return)) then lib$signal(return);
		  end
		else
		  begin
			return:=$faol(dsc_buffer, fao_buffer.length,
				fao_buffer.body, fao_block);
			if (not odd(return)) then lib$signal(return);

			correct_English(fao_buffer);

			return:=put_scroll_dx(column, fao_buffer, attributes);
			if (not odd(return)) then lib$signal(return);

			(* Move any remaining $fao args to index 1 *)
			for i := 1 to fao_count - line_fao_count do
			begin
			    fao_block[i] := fao_block[line_fao_count + i];
			end;
			fao_count := fao_count - line_fao_count;
		  end;
	  end;
end;

[asynchronous, global] function ifc$message_indent(
	message_codes : [list] unsigned) : unsigned;
var	i, j, fao_count, column : integer;
	message_code : unsigned;
	num_codes : unsigned;
	tmp_fao : array[1..8] of integer;
begin
	establish(lib$sig_to_ret);

(*	$begin_display_update(main_display);*)
	num_codes := Argument_List_Length(message_codes);
	column := Argument(message_codes, 1); i:=2;
	while (i<=num_codes) do
	  begin
		message_code:=Argument(message_codes, i); i:=i+1;
		if (i<=num_codes) then
		  begin
			fao_count:=Argument(message_codes, i); i:=i+1;
		  end
		else	fao_count:=0;
		if (fao_count=0) then
			write_message(column, message_code, 0, tmp_fao)
		else
		  begin
			for j := 1 to fao_count do
			begin
			  tmp_fao[j] := argument(message_codes, i+j-1);
			end;
			write_message(column, message_code, fao_count, tmp_fao);
			i:=i+fao_count;
		  end;
	  end;
(*	$end_display_update(main_display);*)

	ifc$message_indent:=1;
end;

[asynchronous, global] function ifc$message(
	message_codes : [list] unsigned) : unsigned;
var	i, j, fao_count : integer;
	message_code : unsigned;
	num_codes : unsigned;
	tmp_fao : array[1..8] of integer;
begin
	establish(lib$sig_to_ret);

(*	$begin_display_update(main_display);*)

	num_codes := Argument_List_Length(message_codes);
	i:=1;
	while (i<=num_codes) do
	  begin
		message_code:=Argument(message_codes, i); i:=i+1;
		if (i<=num_codes) then
		  begin
			fao_count:=Argument(message_codes, i); i:=i+1;
		  end
		else	fao_count:=0;
		if (fao_count=0) then
			write_message(1, message_code, 0, tmp_fao)
		else
		  begin
			for j := 1 to fao_count do
			begin
			  tmp_fao[j] := argument(message_codes, i+j-1);
			end;
			write_message(1, message_code, fao_count, tmp_fao);
			i:=i+fao_count;
		  end;
	  end;
(*	$end_display_update(main_display);*)

	ifc$message:=1;
end;

[global] function ifc$output_broadcast_messages : unsigned;
var	return : unsigned;
	message : varying[255] of char;
begin
	return:=smg$get_broadcast_message(screen, %descr message);
	while ( odd(return) and (return<>smg$_no_mormsg) ) do
	  begin
		return:=smg$put_with_scroll(main_display, message,,
						smg$m_reverse,,1);
		if (odd(return)) then
			return:=smg$get_broadcast_message(screen, %descr message);
	  end;
	ifc$output_broadcast_messages:=return;
end;

end.
