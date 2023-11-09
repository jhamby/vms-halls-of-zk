module types;

type	$ubyte = [byte] 0..2**8-1;
	$byte = [byte] -(2**7)..2**7-1;
	$uword = [word] 0..2**16-1;
	$quad  = [quad, unsafe] record l0 : unsigned; l1 : integer end;
	$uquad = [quad, unsafe] record l0, l1 : unsigned end;
	$item = record
			buffer_length : $uword;
			item_code : $uword;
			buffer_address : unsigned;
			return_length_address : unsigned;
		end;
	$item_list = packed array[1..10] of $item;
end.
