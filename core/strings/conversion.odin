package strings

import "core:unicode"
import "core:unicode/utf8"

to_valid_utf8 :: proc(s, replacement: string, allocator := context.allocator) -> string {
	if len(s) == 0 {
		return "";
	}

	b := make_builder_len_cap(0, 0, allocator);

	s := s;
	for c, i in s {
		if c != utf8.RUNE_ERROR {
			continue;
		}

		_, w := utf8.decode_rune_in_string(s[i:]);
		if w == 1 {
			grow_builder(&b, len(s) + len(replacement));
			write_string(&b, s[:i]);
			s = s[i:];
			break;
		}
	}

	if builder_cap(b) == 0 {
		return clone(s, allocator);
	}

	invalid := false;

	for i := 0; i < len(s); /**/ {
		c := s[i];
		if c < utf8.RUNE_SELF {
			i += 1;
			invalid = false;
			write_byte(&b, c);
			continue;
		}

		_, w := utf8.decode_rune_in_string(s[i:]);
		if w == 1 {
			i += 1;
			if !invalid {
				invalid = true;
				write_string(&b, replacement);
			}
			continue;
		}
		invalid = false;
		write_string(&b, s[i:][:w]);
		i += w;
	}
	return to_string(b);
}

to_lower :: proc(s: string, allocator := context.allocator) -> string {
	b := make_builder(0, len(s), allocator);
	for r in s {
		write_rune(&b, unicode.to_lower(r));
	}
	return to_string(b);
}
to_upper :: proc(s: string, allocator := context.allocator) -> string {
	b := make_builder(0, len(s), allocator);
	for r in s {
		write_rune(&b, unicode.to_upper(r));
	}
	return to_string(b);
}




is_delimiter :: proc(c: rune) -> bool {
	return c == '-' || c == '_' || is_space(c);
}

is_separator :: proc(r: rune) -> bool {
	if r <= 0x7f {
		switch r {
		case '0'..'9': return false;
		case 'a'..'z': return false;
		case 'A'..'Z': return false;
		case '_': return false;
		}
		return true;
	}

	// TODO(bill): unicode categories
	// if unicode.is_letter(r) || unicode.is_digit(r) {
	// 	return false;
	// }

	return unicode.is_space(r);
}


string_case_iterator :: proc(b: ^Builder, s: string, callback: proc(b: ^Builder, prev, curr, next: rune)) {
	prev, curr: rune;
	for next in s {
		if curr == 0 {
			prev = curr;
			curr = next;
			continue;
		}

		callback(b, prev, curr, next);

		prev = curr;
		curr = next;
	}

	if len(s) > 0 {
		callback(b, prev, curr, 0);
	}
}


to_lower_camel_case :: to_camel_case;
to_camel_case :: proc(s: string, allocator := context.allocator) -> string {
	s := s;
	s = trim_space(s);
	b := make_builder(0, len(s), allocator);

	string_case_iterator(&b, s, proc(b: ^Builder, prev, curr, next: rune) {
		if !is_delimiter(curr) {
			if is_delimiter(prev) {
				write_rune(b, unicode.to_upper(curr));
			} else if unicode.is_lower(prev) {
				write_rune(b, curr);
			} else {
				write_rune(b, unicode.to_lower(curr));
			}
		}
	});

	return to_string(b);
}

to_upper_camel_case :: to_pascal_case;
to_pascal_case :: proc(s: string, allocator := context.allocator) -> string {
	s := s;
	s = trim_space(s);
	b := make_builder(0, len(s), allocator);

	string_case_iterator(&b, s, proc(b: ^Builder, prev, curr, next: rune) {
		if !is_delimiter(curr) {
			if is_delimiter(prev) || prev == 0 {
				write_rune(b, unicode.to_upper(curr));
			} else if unicode.is_lower(prev) {
				write_rune(b, curr);
			} else {
				write_rune(b, unicode.to_lower(curr));
			}
		}
	});

	return to_string(b);
}

to_delimiter_case :: proc(s: string, delimiter: rune, all_upper_case: bool, allocator := context.allocator) -> string {
	s := s;
	s = trim_space(s);
	b := make_builder(0, len(s), allocator);

	adjust_case := unicode.to_upper if all_upper_case else unicode.to_lower;

	prev, curr: rune;

	for next in s {
		if is_delimiter(curr) {
			if !is_delimiter(prev) {
				write_rune(&b, delimiter);
			}
		} else if unicode.is_upper(curr) {
			if unicode.is_lower(prev) || (unicode.is_upper(prev) && unicode.is_lower(next)) {
				write_rune(&b, delimiter);
			}
			write_rune(&b, adjust_case(curr));
		} else if curr != 0 {
			write_rune(&b, adjust_case(curr));
		}

		prev = curr;
		curr = next;
	}

	if len(s) > 0 {
		if unicode.is_upper(curr) && unicode.is_lower(prev) && prev != 0 {
			write_rune(&b, delimiter);
		}
		write_rune(&b, adjust_case(curr));
	}

	return to_string(b);
}


to_snake_case :: proc(s: string, allocator := context.allocator) -> string {
	return to_delimiter_case(s, '_', false, allocator);
}

to_screaming_snake_case :: to_upper_snake_case;
to_upper_snake_case :: proc(s: string, allocator := context.allocator) -> string {
	return to_delimiter_case(s, '_', true, allocator);
}

to_kebab_case :: proc(s: string, allocator := context.allocator) -> string {
	return to_delimiter_case(s, '-', false, allocator);
}

to_upper_case :: proc(s: string, allocator := context.allocator) -> string {
	return to_delimiter_case(s, '-', true, allocator);
}

to_ada_case :: proc(s: string, allocator := context.allocator) -> string {
	delimiter :: '_';

	s := s;
	s = trim_space(s);
	b := make_builder(0, len(s), allocator);

	prev, curr: rune;

	for next in s {
		if is_delimiter(curr) {
			if !is_delimiter(prev) {
				write_rune(&b, delimiter);
			}
		} else if unicode.is_upper(curr) {
			if unicode.is_lower(prev) || (unicode.is_upper(prev) && unicode.is_lower(next)) {
				write_rune(&b, delimiter);
			}
			write_rune(&b, unicode.to_upper(curr));
		} else if curr != 0 {
			write_rune(&b, unicode.to_lower(curr));
		}

		prev = curr;
		curr = next;
	}

	if len(s) > 0 {
		if unicode.is_upper(curr) && unicode.is_lower(prev) && prev != 0 {
			write_rune(&b, delimiter);
			write_rune(&b, unicode.to_upper(curr));
		} else {
			write_rune(&b, unicode.to_lower(curr));
		}
	}

	return to_string(b);
}

