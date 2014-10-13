####################################################################
#
# ANY CHANGE MADE HERE WILL BE LOST !
#
# This file was generated using Parse::Yapp version 1.05.
# Don't edit this file, edit template.skel.pm and template.yp instead.
#
####################################################################

package VMXTemplate::Parser;

use strict;
use base qw(Parse::Yapp::Driver VMXTemplate::Compiler);
use VMXTemplate::Utils;
use Parse::Yapp::Driver;


sub new
{
    my $class = shift;
    $class = ref($class) || $class;
    my ($options) = @_;
    my $self = bless $class->SUPER::new(
        yyversion => '1.05',
        yystates =>
[
	{#State 0
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 2,
			'template' => 1
		}
	},
	{#State 1
		ACTIONS => {
			'' => 3
		}
	},
	{#State 2
		ACTIONS => {
			"{{" => 4,
			"<!--" => 6,
			'error' => 7,
			'' => -1,
			'literal' => 8
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 3
		DEFAULT => 0
	},
	{#State 4
		ACTIONS => {
			"-" => 12,
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'varref' => 15,
			'nonbrace' => 9,
			'exp' => 17
		}
	},
	{#State 5
		DEFAULT => -3
	},
	{#State 6
		ACTIONS => {
			"FOR" => 23,
			"{" => 10,
			"BLOCK" => 31,
			"NOT" => 11,
			"-" => 12,
			"IF" => 30,
			"(" => 16,
			"SET" => 35,
			"FUNCTION" => 27,
			"FOREACH" => 26,
			'literal' => 18,
			'name' => 19,
			"MACRO" => 33,
			"!" => 20
		},
		GOTOS => {
			'c_for' => 22,
			'nonbrace' => 9,
			'code_chunk' => 32,
			'p10' => 13,
			'p11' => 14,
			'fn_def' => 29,
			'for' => 28,
			'fn' => 21,
			'exp' => 34,
			'c_fn' => 25,
			'c_if' => 36,
			'varref' => 15,
			'c_set' => 24
		}
	},
	{#State 7
		DEFAULT => -7
	},
	{#State 8
		DEFAULT => -4
	},
	{#State 9
		DEFAULT => -54
	},
	{#State 10
		ACTIONS => {
			"NOT" => 11,
			"{" => 10,
			"-" => 12,
			"(" => 16,
			'name' => 19,
			'literal' => 18,
			"!" => 20
		},
		DEFAULT => -72,
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'nonbrace' => 9,
			'gtpair' => 39,
			'exp' => 38,
			'varref' => 15,
			'pair' => 40,
			'hash' => 37
		}
	},
	{#State 11
		ACTIONS => {
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"(" => 16,
			"NOT" => 11,
			"{" => 10
		},
		GOTOS => {
			'p11' => 41,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 12
		ACTIONS => {
			"!" => 20,
			'literal' => 18,
			'name' => 19,
			"(" => 16,
			"NOT" => 11,
			"{" => 10
		},
		GOTOS => {
			'varref' => 15,
			'nonbrace' => 9,
			'p11' => 42
		}
	},
	{#State 13
		DEFAULT => -51
	},
	{#State 14
		DEFAULT => -52
	},
	{#State 15
		ACTIONS => {
			"[" => 43,
			"." => 44
		},
		DEFAULT => -60,
		GOTOS => {
			'varpart' => 45
		}
	},
	{#State 16
		ACTIONS => {
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"!" => 20,
			'name' => 19,
			'literal' => 18
		},
		GOTOS => {
			'varref' => 15,
			'exp' => 46,
			'nonbrace' => 9,
			'p11' => 14,
			'p10' => 13
		}
	},
	{#State 17
		ACTIONS => {
			"!=" => 64,
			"AND" => 65,
			"&" => 59,
			"%" => 58,
			"OR" => 63,
			".." => 61,
			">=" => 60,
			"&&" => 62,
			"==" => 54,
			"}}" => 56,
			"<=" => 57,
			"*" => 55,
			"-" => 50,
			">" => 52,
			"XOR" => 51,
			"/" => 47,
			"+" => 49,
			"<" => 48,
			"||" => 53
		}
	},
	{#State 18
		DEFAULT => -59
	},
	{#State 19
		ACTIONS => {
			"(" => 67,
			'literal' => 18,
			"{" => 10,
			'name' => 19
		},
		DEFAULT => -78,
		GOTOS => {
			'varref' => 15,
			'nonbrace' => 66
		}
	},
	{#State 20
		ACTIONS => {
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'p11' => 68,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 21
		ACTIONS => {
			'name' => 69
		}
	},
	{#State 22
		DEFAULT => -11
	},
	{#State 23
		DEFAULT => -28
	},
	{#State 24
		DEFAULT => -9
	},
	{#State 25
		DEFAULT => -10
	},
	{#State 26
		DEFAULT => -29
	},
	{#State 27
		DEFAULT => -25
	},
	{#State 28
		ACTIONS => {
			'name' => 71
		},
		GOTOS => {
			'varref' => 70
		}
	},
	{#State 29
		ACTIONS => {
			"-->" => 73,
			"=" => 72
		}
	},
	{#State 30
		ACTIONS => {
			"!" => 20,
			'name' => 19,
			'literal' => 18,
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'nonbrace' => 9,
			'exp' => 74,
			'varref' => 15
		}
	},
	{#State 31
		DEFAULT => -26
	},
	{#State 32
		ACTIONS => {
			"-->" => 75
		}
	},
	{#State 33
		DEFAULT => -27
	},
	{#State 34
		ACTIONS => {
			">=" => 60,
			"&&" => 62,
			".." => 61,
			"OR" => 63,
			"%" => 58,
			"&" => 59,
			"AND" => 65,
			"!=" => 64,
			"||" => 53,
			"+" => 49,
			"<" => 48,
			"/" => 47,
			"XOR" => 51,
			"-" => 50,
			">" => 52,
			"*" => 55,
			"<=" => 57,
			"==" => 54
		},
		DEFAULT => -12
	},
	{#State 35
		ACTIONS => {
			'name' => 71
		},
		GOTOS => {
			'varref' => 76
		}
	},
	{#State 36
		DEFAULT => -8
	},
	{#State 37
		ACTIONS => {
			"}" => 77
		}
	},
	{#State 38
		ACTIONS => {
			"AND" => 65,
			"!=" => 64,
			"OR" => 63,
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"&" => 59,
			"%" => 58,
			"<=" => 57,
			"*" => 55,
			"==" => 54,
			"," => 79,
			"||" => 53,
			"-" => 50,
			">" => 52,
			"XOR" => 51,
			"=>" => 78,
			"<" => 48,
			"+" => 49,
			"/" => 47
		}
	},
	{#State 39
		DEFAULT => -76
	},
	{#State 40
		ACTIONS => {
			"," => 80
		},
		DEFAULT => -70
	},
	{#State 41
		DEFAULT => -57
	},
	{#State 42
		DEFAULT => -53
	},
	{#State 43
		ACTIONS => {
			"!" => 20,
			'name' => 19,
			'literal' => 18,
			"-" => 12,
			"(" => 16,
			"{" => 10,
			"NOT" => 11
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'varref' => 15,
			'exp' => 81,
			'nonbrace' => 9
		}
	},
	{#State 44
		ACTIONS => {
			'name' => 82
		}
	},
	{#State 45
		DEFAULT => -79
	},
	{#State 46
		ACTIONS => {
			"!=" => 64,
			"AND" => 65,
			"%" => 58,
			"&" => 59,
			"&&" => 62,
			">=" => 60,
			".." => 61,
			"OR" => 63,
			"==" => 54,
			")" => 83,
			"*" => 55,
			"<=" => 57,
			"/" => 47,
			"<" => 48,
			"+" => 49,
			">" => 52,
			"XOR" => 51,
			"-" => 50,
			"||" => 53
		}
	},
	{#State 47
		ACTIONS => {
			"(" => 16,
			"NOT" => 11,
			"{" => 10,
			"-" => 12,
			'literal' => 18,
			'name' => 19,
			"!" => 20
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'varref' => 15,
			'exp' => 84,
			'nonbrace' => 9
		}
	},
	{#State 48
		ACTIONS => {
			"-" => 12,
			"(" => 16,
			"NOT" => 11,
			"{" => 10,
			"!" => 20,
			'name' => 19,
			'literal' => 18
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'nonbrace' => 9,
			'exp' => 85,
			'varref' => 15
		}
	},
	{#State 49
		ACTIONS => {
			"!" => 20,
			'literal' => 18,
			'name' => 19,
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16
		},
		GOTOS => {
			'nonbrace' => 9,
			'exp' => 86,
			'varref' => 15,
			'p11' => 14,
			'p10' => 13
		}
	},
	{#State 50
		ACTIONS => {
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"(" => 16,
			"NOT" => 11,
			"{" => 10,
			"-" => 12
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'exp' => 87,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 51
		ACTIONS => {
			"-" => 12,
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'varref' => 15,
			'exp' => 88,
			'nonbrace' => 9,
			'p11' => 14,
			'p10' => 13
		}
	},
	{#State 52
		ACTIONS => {
			"(" => 16,
			"{" => 10,
			"NOT" => 11,
			"-" => 12,
			'name' => 19,
			'literal' => 18,
			"!" => 20
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'exp' => 89,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 53
		ACTIONS => {
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"-" => 12,
			'name' => 19,
			'literal' => 18,
			"!" => 20
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'nonbrace' => 9,
			'exp' => 90,
			'varref' => 15
		}
	},
	{#State 54
		ACTIONS => {
			"(" => 16,
			"{" => 10,
			"NOT" => 11,
			"-" => 12,
			'literal' => 18,
			'name' => 19,
			"!" => 20
		},
		GOTOS => {
			'exp' => 91,
			'nonbrace' => 9,
			'varref' => 15,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 55
		ACTIONS => {
			"!" => 20,
			'name' => 19,
			'literal' => 18,
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'nonbrace' => 9,
			'exp' => 92,
			'varref' => 15
		}
	},
	{#State 56
		DEFAULT => -6
	},
	{#State 57
		ACTIONS => {
			'literal' => 18,
			'name' => 19,
			"!" => 20,
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"-" => 12
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'exp' => 93,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 58
		ACTIONS => {
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"-" => 12
		},
		GOTOS => {
			'nonbrace' => 9,
			'exp' => 94,
			'varref' => 15,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 59
		ACTIONS => {
			"-" => 12,
			"(" => 16,
			"{" => 10,
			"NOT" => 11,
			"!" => 20,
			'name' => 19,
			'literal' => 18
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'exp' => 95,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 60
		ACTIONS => {
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"-" => 12,
			'name' => 19,
			'literal' => 18,
			"!" => 20
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'varref' => 15,
			'exp' => 96,
			'nonbrace' => 9
		}
	},
	{#State 61
		ACTIONS => {
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"!" => 20,
			'name' => 19,
			'literal' => 18
		},
		GOTOS => {
			'nonbrace' => 9,
			'exp' => 97,
			'varref' => 15,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 62
		ACTIONS => {
			"-" => 12,
			"(" => 16,
			"NOT" => 11,
			"{" => 10,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'varref' => 15,
			'nonbrace' => 9,
			'exp' => 98,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 63
		ACTIONS => {
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"!" => 20,
			'name' => 19,
			'literal' => 18
		},
		GOTOS => {
			'varref' => 15,
			'nonbrace' => 9,
			'exp' => 99,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 64
		ACTIONS => {
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"!" => 20,
			'name' => 19,
			'literal' => 18
		},
		GOTOS => {
			'varref' => 15,
			'exp' => 100,
			'nonbrace' => 9,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 65
		ACTIONS => {
			"(" => 16,
			"NOT" => 11,
			"{" => 10,
			"-" => 12,
			'literal' => 18,
			'name' => 19,
			"!" => 20
		},
		GOTOS => {
			'p11' => 14,
			'p10' => 13,
			'varref' => 15,
			'exp' => 101,
			'nonbrace' => 9
		}
	},
	{#State 66
		DEFAULT => -64
	},
	{#State 67
		ACTIONS => {
			"{" => 10,
			"NOT" => 11,
			"-" => 12,
			"(" => 16,
			")" => 105,
			'name' => 19,
			'literal' => 18,
			"!" => 20
		},
		GOTOS => {
			'gtpair' => 102,
			'list' => 103,
			'p10' => 13,
			'p11' => 14,
			'nonbrace' => 9,
			'gthash' => 104,
			'exp' => 106,
			'varref' => 15
		}
	},
	{#State 68
		DEFAULT => -56
	},
	{#State 69
		ACTIONS => {
			"(" => 107
		}
	},
	{#State 70
		ACTIONS => {
			"[" => 43,
			"=" => 108,
			"." => 44
		},
		GOTOS => {
			'varpart' => 45
		}
	},
	{#State 71
		DEFAULT => -78
	},
	{#State 72
		ACTIONS => {
			"!" => 20,
			'name' => 19,
			'literal' => 18,
			"-" => 12,
			"(" => 16,
			"{" => 10,
			"NOT" => 11
		},
		GOTOS => {
			'varref' => 15,
			'exp' => 109,
			'nonbrace' => 9,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 73
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 110
		}
	},
	{#State 74
		ACTIONS => {
			"||" => 53,
			"XOR" => 51,
			"-" => 50,
			">" => 52,
			"-->" => 111,
			"/" => 47,
			"<" => 48,
			"+" => 49,
			"<=" => 57,
			"*" => 55,
			"==" => 54,
			"OR" => 63,
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"&" => 59,
			"%" => 58,
			"AND" => 65,
			"!=" => 64
		}
	},
	{#State 75
		DEFAULT => -5
	},
	{#State 76
		ACTIONS => {
			"." => 44,
			"-->" => 112,
			"=" => 113,
			"[" => 43
		},
		GOTOS => {
			'varpart' => 45
		}
	},
	{#State 77
		DEFAULT => -58
	},
	{#State 78
		ACTIONS => {
			"-" => 12,
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'exp' => 114,
			'nonbrace' => 9,
			'varref' => 15
		}
	},
	{#State 79
		ACTIONS => {
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"-" => 12
		},
		GOTOS => {
			'varref' => 15,
			'exp' => 115,
			'nonbrace' => 9,
			'p10' => 13,
			'p11' => 14
		}
	},
	{#State 80
		ACTIONS => {
			"(" => 16,
			"!" => 20,
			'name' => 19,
			'literal' => 18,
			"-" => 12,
			"{" => 10,
			"NOT" => 11
		},
		DEFAULT => -72,
		GOTOS => {
			'gtpair' => 39,
			'p11' => 14,
			'p10' => 13,
			'nonbrace' => 9,
			'pair' => 40,
			'hash' => 116,
			'exp' => 38,
			'varref' => 15
		}
	},
	{#State 81
		ACTIONS => {
			"%" => 58,
			"&" => 59,
			"&&" => 62,
			">=" => 60,
			".." => 61,
			"OR" => 63,
			"!=" => 64,
			"AND" => 65,
			"<" => 48,
			"+" => 49,
			"]" => 117,
			"/" => 47,
			"XOR" => 51,
			">" => 52,
			"-" => 50,
			"||" => 53,
			"==" => 54,
			"*" => 55,
			"<=" => 57
		}
	},
	{#State 82
		ACTIONS => {
			"(" => 118
		},
		DEFAULT => -80
	},
	{#State 83
		DEFAULT => -84,
		GOTOS => {
			'varpath' => 119
		}
	},
	{#State 84
		DEFAULT => -49
	},
	{#State 85
		ACTIONS => {
			"==" => undef,
			"*" => 55,
			"<=" => undef,
			"+" => 49,
			"<" => undef,
			"/" => 47,
			"-" => 50,
			">" => undef,
			"!=" => undef,
			"%" => 58,
			"&" => 59,
			">=" => undef
		},
		DEFAULT => -41
	},
	{#State 86
		ACTIONS => {
			"%" => 58,
			"&" => 59,
			"*" => 55,
			"/" => 47
		},
		DEFAULT => -45
	},
	{#State 87
		ACTIONS => {
			"/" => 47,
			"*" => 55,
			"&" => 59,
			"%" => 58
		},
		DEFAULT => -46
	},
	{#State 88
		ACTIONS => {
			"==" => 54,
			"*" => 55,
			"<=" => 57,
			"+" => 49,
			"<" => 48,
			"/" => 47,
			">" => 52,
			"-" => 50,
			"!=" => 64,
			"AND" => 65,
			"%" => 58,
			"&" => 59,
			">=" => 60,
			"&&" => 62
		},
		DEFAULT => -36
	},
	{#State 89
		ACTIONS => {
			"<=" => undef,
			"*" => 55,
			"==" => undef,
			"-" => 50,
			">" => undef,
			"/" => 47,
			"+" => 49,
			"<" => undef,
			"!=" => undef,
			">=" => undef,
			"&" => 59,
			"%" => 58
		},
		DEFAULT => -42
	},
	{#State 90
		ACTIONS => {
			"&" => 59,
			"%" => 58,
			"&&" => 62,
			">=" => 60,
			"!=" => 64,
			"AND" => 65,
			">" => 52,
			"-" => 50,
			"/" => 47,
			"+" => 49,
			"<" => 48,
			"==" => 54,
			"<=" => 57,
			"*" => 55
		},
		DEFAULT => -34
	},
	{#State 91
		ACTIONS => {
			"*" => 55,
			"<=" => undef,
			"==" => undef,
			"/" => 47,
			"+" => 49,
			"<" => undef,
			">" => undef,
			"-" => 50,
			"!=" => undef,
			">=" => undef,
			"%" => 58,
			"&" => 59
		},
		DEFAULT => -39
	},
	{#State 92
		DEFAULT => -48
	},
	{#State 93
		ACTIONS => {
			"&" => 59,
			"%" => 58,
			">=" => undef,
			"!=" => undef,
			">" => undef,
			"-" => 50,
			"/" => 47,
			"+" => 49,
			"<" => undef,
			"==" => undef,
			"<=" => undef,
			"*" => 55
		},
		DEFAULT => -43
	},
	{#State 94
		DEFAULT => -50
	},
	{#State 95
		ACTIONS => {
			"*" => 55,
			"/" => 47,
			"%" => 58
		},
		DEFAULT => -47
	},
	{#State 96
		ACTIONS => {
			"<=" => undef,
			"*" => 55,
			"==" => undef,
			">" => undef,
			"-" => 50,
			"/" => 47,
			"<" => undef,
			"+" => 49,
			"!=" => undef,
			">=" => undef,
			"&" => 59,
			"%" => 58
		},
		DEFAULT => -44
	},
	{#State 97
		ACTIONS => {
			"<=" => 57,
			"*" => 55,
			"==" => 54,
			"||" => 53,
			"XOR" => 51,
			"-" => 50,
			">" => 52,
			"+" => 49,
			"<" => 48,
			"/" => 47,
			"AND" => 65,
			"!=" => 64,
			"OR" => 63,
			"&&" => 62,
			">=" => 60,
			"&" => 59,
			"%" => 58
		},
		DEFAULT => -33
	},
	{#State 98
		ACTIONS => {
			"==" => 54,
			"*" => 55,
			"<=" => 57,
			"+" => 49,
			"<" => 48,
			"/" => 47,
			">" => 52,
			"-" => 50,
			"!=" => 64,
			"%" => 58,
			"&" => 59,
			">=" => 60
		},
		DEFAULT => -37
	},
	{#State 99
		ACTIONS => {
			"AND" => 65,
			"!=" => 64,
			"&&" => 62,
			">=" => 60,
			"%" => 58,
			"&" => 59,
			"*" => 55,
			"<=" => 57,
			"==" => 54,
			"<" => 48,
			"+" => 49,
			"/" => 47,
			"-" => 50,
			">" => 52
		},
		DEFAULT => -35
	},
	{#State 100
		ACTIONS => {
			"!=" => undef,
			">=" => undef,
			"&" => 59,
			"%" => 58,
			"<=" => undef,
			"*" => 55,
			"==" => undef,
			">" => undef,
			"-" => 50,
			"/" => 47,
			"<" => undef,
			"+" => 49
		},
		DEFAULT => -40
	},
	{#State 101
		ACTIONS => {
			"*" => 55,
			"<=" => 57,
			"==" => 54,
			"<" => 48,
			"+" => 49,
			"/" => 47,
			">" => 52,
			"-" => 50,
			"!=" => 64,
			">=" => 60,
			"%" => 58,
			"&" => 59
		},
		DEFAULT => -38
	},
	{#State 102
		ACTIONS => {
			"," => 120
		},
		DEFAULT => -73
	},
	{#State 103
		ACTIONS => {
			")" => 121
		}
	},
	{#State 104
		ACTIONS => {
			")" => 122
		}
	},
	{#State 105
		DEFAULT => -61
	},
	{#State 106
		ACTIONS => {
			"==" => 54,
			"*" => 55,
			"<=" => 57,
			"/" => 47,
			"<" => 48,
			"+" => 49,
			"=>" => 78,
			"XOR" => 51,
			"-" => 50,
			">" => 52,
			"||" => 53,
			"," => 123,
			"!=" => 64,
			"AND" => 65,
			"%" => 58,
			"&" => 59,
			">=" => 60,
			".." => 61,
			"&&" => 62,
			"OR" => 63
		},
		DEFAULT => -65
	},
	{#State 107
		ACTIONS => {
			'name' => 125
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 124
		}
	},
	{#State 108
		ACTIONS => {
			"!" => 20,
			'name' => 19,
			'literal' => 18,
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16
		},
		GOTOS => {
			'nonbrace' => 9,
			'exp' => 126,
			'varref' => 15,
			'p11' => 14,
			'p10' => 13
		}
	},
	{#State 109
		ACTIONS => {
			"*" => 55,
			"<=" => 57,
			"==" => 54,
			"||" => 53,
			"+" => 49,
			"<" => 48,
			"/" => 47,
			">" => 52,
			"XOR" => 51,
			"-" => 50,
			"AND" => 65,
			"!=" => 64,
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"OR" => 63,
			"%" => 58,
			"&" => 59
		},
		DEFAULT => -22
	},
	{#State 110
		ACTIONS => {
			'error' => 7,
			"{{" => 4,
			"<!--" => 127,
			'literal' => 8
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 111
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 128
		}
	},
	{#State 112
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 129
		}
	},
	{#State 113
		ACTIONS => {
			"(" => 16,
			"{" => 10,
			"NOT" => 11,
			"-" => 12,
			'literal' => 18,
			'name' => 19,
			"!" => 20
		},
		GOTOS => {
			'varref' => 15,
			'nonbrace' => 9,
			'exp' => 130,
			'p11' => 14,
			'p10' => 13
		}
	},
	{#State 114
		ACTIONS => {
			"/" => 47,
			"+" => 49,
			"<" => 48,
			">" => 52,
			"-" => 50,
			"XOR" => 51,
			"||" => 53,
			"==" => 54,
			"*" => 55,
			"<=" => 57,
			"%" => 58,
			"&" => 59,
			"&&" => 62,
			">=" => 60,
			".." => 61,
			"OR" => 63,
			"!=" => 64,
			"AND" => 65
		},
		DEFAULT => -77
	},
	{#State 115
		ACTIONS => {
			">" => 52,
			"XOR" => 51,
			"-" => 50,
			"/" => 47,
			"+" => 49,
			"<" => 48,
			"||" => 53,
			"==" => 54,
			"<=" => 57,
			"*" => 55,
			"&" => 59,
			"%" => 58,
			"OR" => 63,
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"!=" => 64,
			"AND" => 65
		},
		DEFAULT => -75
	},
	{#State 116
		DEFAULT => -71
	},
	{#State 117
		DEFAULT => -81
	},
	{#State 118
		ACTIONS => {
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			")" => 131,
			"(" => 16,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'nonbrace' => 9,
			'exp' => 133,
			'varref' => 15,
			'p11' => 14,
			'p10' => 13,
			'list' => 132
		}
	},
	{#State 119
		ACTIONS => {
			"[" => 43,
			"." => 44
		},
		DEFAULT => -55,
		GOTOS => {
			'varpart' => 134
		}
	},
	{#State 120
		ACTIONS => {
			'literal' => 18,
			'name' => 19,
			"!" => 20,
			"{" => 10,
			"NOT" => 11,
			"(" => 16,
			"-" => 12
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'varref' => 15,
			'nonbrace' => 9,
			'exp' => 135,
			'gthash' => 136,
			'gtpair' => 102
		}
	},
	{#State 121
		DEFAULT => -62
	},
	{#State 122
		DEFAULT => -63
	},
	{#State 123
		ACTIONS => {
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"(" => 16,
			"NOT" => 11,
			"{" => 10,
			"-" => 12
		},
		GOTOS => {
			'list' => 137,
			'varref' => 15,
			'exp' => 133,
			'nonbrace' => 9,
			'p11' => 14,
			'p10' => 13
		}
	},
	{#State 124
		ACTIONS => {
			")" => 138
		}
	},
	{#State 125
		ACTIONS => {
			"," => 139
		},
		DEFAULT => -67
	},
	{#State 126
		ACTIONS => {
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"OR" => 63,
			"%" => 58,
			"&" => 59,
			"AND" => 65,
			"!=" => 64,
			"||" => 53,
			"/" => 47,
			"+" => 49,
			"<" => 48,
			"XOR" => 51,
			"-->" => 140,
			">" => 52,
			"-" => 50,
			"*" => 55,
			"<=" => 57,
			"==" => 54
		}
	},
	{#State 127
		ACTIONS => {
			"SET" => 35,
			"(" => 16,
			"FUNCTION" => 27,
			"FOREACH" => 26,
			'literal' => 18,
			'name' => 19,
			"MACRO" => 33,
			"!" => 20,
			"FOR" => 23,
			"{" => 10,
			"NOT" => 11,
			"BLOCK" => 31,
			"-" => 12,
			"END" => 141,
			"IF" => 30
		},
		GOTOS => {
			'c_set' => 24,
			'varref' => 15,
			'c_if' => 36,
			'c_fn' => 25,
			'exp' => 34,
			'fn' => 21,
			'fn_def' => 29,
			'for' => 28,
			'p10' => 13,
			'p11' => 14,
			'code_chunk' => 32,
			'c_for' => 22,
			'nonbrace' => 9
		}
	},
	{#State 128
		ACTIONS => {
			'literal' => 8,
			'error' => 7,
			"<!--" => 142,
			"{{" => 4
		},
		GOTOS => {
			'c_elseifs' => 143,
			'chunk' => 5
		}
	},
	{#State 129
		ACTIONS => {
			"{{" => 4,
			"<!--" => 144,
			'error' => 7,
			'literal' => 8
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 130
		ACTIONS => {
			"<=" => 57,
			"*" => 55,
			"==" => 54,
			"||" => 53,
			">" => 52,
			"-" => 50,
			"XOR" => 51,
			"/" => 47,
			"+" => 49,
			"<" => 48,
			"AND" => 65,
			"!=" => 64,
			"OR" => 63,
			">=" => 60,
			".." => 61,
			"&&" => 62,
			"&" => 59,
			"%" => 58
		},
		DEFAULT => -19
	},
	{#State 131
		DEFAULT => -82
	},
	{#State 132
		ACTIONS => {
			")" => 145
		}
	},
	{#State 133
		ACTIONS => {
			">" => 52,
			"XOR" => 51,
			"-" => 50,
			"<" => 48,
			"+" => 49,
			"/" => 47,
			"," => 123,
			"||" => 53,
			"==" => 54,
			"<=" => 57,
			"*" => 55,
			"&" => 59,
			"%" => 58,
			"OR" => 63,
			"&&" => 62,
			".." => 61,
			">=" => 60,
			"!=" => 64,
			"AND" => 65
		},
		DEFAULT => -65
	},
	{#State 134
		DEFAULT => -85
	},
	{#State 135
		ACTIONS => {
			"||" => 53,
			"/" => 47,
			"<" => 48,
			"+" => 49,
			"=>" => 78,
			"-" => 50,
			"XOR" => 51,
			">" => 52,
			"*" => 55,
			"<=" => 57,
			"==" => 54,
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"OR" => 63,
			"%" => 58,
			"&" => 59,
			"AND" => 65,
			"!=" => 64
		}
	},
	{#State 136
		DEFAULT => -74
	},
	{#State 137
		DEFAULT => -66
	},
	{#State 138
		DEFAULT => -21
	},
	{#State 139
		ACTIONS => {
			'name' => 125
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 146
		}
	},
	{#State 140
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 147
		}
	},
	{#State 141
		DEFAULT => -23
	},
	{#State 142
		ACTIONS => {
			"FUNCTION" => 27,
			"FOREACH" => 26,
			'name' => 19,
			"ELSEIF" => 152,
			"!" => 20,
			"FOR" => 23,
			"NOT" => 11,
			"{" => 10,
			"-" => 12,
			"ELSE" => 150,
			"END" => 151,
			"(" => 16,
			"SET" => 35,
			"ELSIF" => 149,
			'literal' => 18,
			"MACRO" => 33,
			"BLOCK" => 31,
			"IF" => 30
		},
		GOTOS => {
			'code_chunk' => 32,
			'nonbrace' => 9,
			'c_for' => 22,
			'p10' => 13,
			'p11' => 14,
			'for' => 28,
			'fn_def' => 29,
			'fn' => 21,
			'varref' => 15,
			'c_if' => 36,
			'c_fn' => 25,
			'exp' => 34,
			'elseif' => 148,
			'c_set' => 24
		}
	},
	{#State 143
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 153
		}
	},
	{#State 144
		ACTIONS => {
			"END" => 154,
			"IF" => 30,
			"FOR" => 23,
			"BLOCK" => 31,
			"NOT" => 11,
			"{" => 10,
			"-" => 12,
			'name' => 19,
			'literal' => 18,
			"MACRO" => 33,
			"!" => 20,
			"(" => 16,
			"SET" => 35,
			"FUNCTION" => 27,
			"FOREACH" => 26
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'code_chunk' => 32,
			'c_for' => 22,
			'nonbrace' => 9,
			'fn' => 21,
			'fn_def' => 29,
			'for' => 28,
			'c_if' => 36,
			'varref' => 15,
			'exp' => 34,
			'c_fn' => 25,
			'c_set' => 24
		}
	},
	{#State 145
		DEFAULT => -83
	},
	{#State 146
		DEFAULT => -68
	},
	{#State 147
		ACTIONS => {
			"<!--" => 155,
			"{{" => 4,
			'error' => 7,
			'literal' => 8
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 148
		ACTIONS => {
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"(" => 16,
			"{" => 10,
			"NOT" => 11,
			"-" => 12
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'varref' => 15,
			'exp' => 156,
			'nonbrace' => 9
		}
	},
	{#State 149
		DEFAULT => -31
	},
	{#State 150
		ACTIONS => {
			"-->" => 158,
			"IF" => 157
		}
	},
	{#State 151
		DEFAULT => -13
	},
	{#State 152
		DEFAULT => -32
	},
	{#State 153
		ACTIONS => {
			'literal' => 8,
			"<!--" => 159,
			"{{" => 4,
			'error' => 7
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 154
		DEFAULT => -20
	},
	{#State 155
		ACTIONS => {
			"(" => 16,
			"SET" => 35,
			"FUNCTION" => 27,
			"FOREACH" => 26,
			'name' => 19,
			'literal' => 18,
			"MACRO" => 33,
			"!" => 20,
			"FOR" => 23,
			"{" => 10,
			"BLOCK" => 31,
			"NOT" => 11,
			"-" => 12,
			"END" => 160,
			"IF" => 30
		},
		GOTOS => {
			'c_if' => 36,
			'varref' => 15,
			'c_fn' => 25,
			'exp' => 34,
			'c_set' => 24,
			'p10' => 13,
			'p11' => 14,
			'code_chunk' => 32,
			'c_for' => 22,
			'nonbrace' => 9,
			'fn' => 21,
			'fn_def' => 29,
			'for' => 28
		}
	},
	{#State 156
		ACTIONS => {
			"<=" => 57,
			"*" => 55,
			"==" => 54,
			"||" => 53,
			"XOR" => 51,
			"-->" => 161,
			">" => 52,
			"-" => 50,
			"/" => 47,
			"+" => 49,
			"<" => 48,
			"AND" => 65,
			"!=" => 64,
			"OR" => 63,
			".." => 61,
			"&&" => 62,
			">=" => 60,
			"&" => 59,
			"%" => 58
		}
	},
	{#State 157
		DEFAULT => -30
	},
	{#State 158
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 162
		}
	},
	{#State 159
		ACTIONS => {
			"MACRO" => 33,
			'literal' => 18,
			"ELSIF" => 149,
			"(" => 16,
			"SET" => 35,
			"IF" => 30,
			"BLOCK" => 31,
			"!" => 20,
			"ELSEIF" => 152,
			'name' => 19,
			"FOREACH" => 26,
			"FUNCTION" => 27,
			"END" => 164,
			"ELSE" => 165,
			"-" => 12,
			"{" => 10,
			"NOT" => 11,
			"FOR" => 23
		},
		GOTOS => {
			'c_if' => 36,
			'varref' => 15,
			'c_fn' => 25,
			'exp' => 34,
			'elseif' => 163,
			'c_set' => 24,
			'code_chunk' => 32,
			'nonbrace' => 9,
			'c_for' => 22,
			'p10' => 13,
			'p11' => 14,
			'for' => 28,
			'fn_def' => 29,
			'fn' => 21
		}
	},
	{#State 160
		DEFAULT => -24
	},
	{#State 161
		DEFAULT => -17
	},
	{#State 162
		ACTIONS => {
			'literal' => 8,
			'error' => 7,
			"<!--" => 166,
			"{{" => 4
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 163
		ACTIONS => {
			"-" => 12,
			"NOT" => 11,
			"{" => 10,
			"(" => 16,
			"!" => 20,
			'literal' => 18,
			'name' => 19
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'varref' => 15,
			'nonbrace' => 9,
			'exp' => 167
		}
	},
	{#State 164
		DEFAULT => -15
	},
	{#State 165
		ACTIONS => {
			"IF" => 157,
			"-->" => 168
		}
	},
	{#State 166
		ACTIONS => {
			"FOREACH" => 26,
			"FUNCTION" => 27,
			"SET" => 35,
			"(" => 16,
			"!" => 20,
			"MACRO" => 33,
			'literal' => 18,
			'name' => 19,
			"-" => 12,
			"BLOCK" => 31,
			"NOT" => 11,
			"{" => 10,
			"FOR" => 23,
			"IF" => 30,
			"END" => 169
		},
		GOTOS => {
			'p10' => 13,
			'p11' => 14,
			'c_for' => 22,
			'nonbrace' => 9,
			'code_chunk' => 32,
			'fn' => 21,
			'for' => 28,
			'fn_def' => 29,
			'c_fn' => 25,
			'exp' => 34,
			'varref' => 15,
			'c_if' => 36,
			'c_set' => 24
		}
	},
	{#State 167
		ACTIONS => {
			"%" => 58,
			"&" => 59,
			">=" => 60,
			".." => 61,
			"&&" => 62,
			"OR" => 63,
			"!=" => 64,
			"AND" => 65,
			"+" => 49,
			"<" => 48,
			"/" => 47,
			"-->" => 170,
			"XOR" => 51,
			">" => 52,
			"-" => 50,
			"||" => 53,
			"==" => 54,
			"*" => 55,
			"<=" => 57
		}
	},
	{#State 168
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 171
		}
	},
	{#State 169
		DEFAULT => -14
	},
	{#State 170
		DEFAULT => -18
	},
	{#State 171
		ACTIONS => {
			'literal' => 8,
			"<!--" => 172,
			"{{" => 4,
			'error' => 7
		},
		GOTOS => {
			'chunk' => 5
		}
	},
	{#State 172
		ACTIONS => {
			"NOT" => 11,
			"BLOCK" => 31,
			"{" => 10,
			"FOR" => 23,
			"-" => 12,
			"END" => 173,
			"IF" => 30,
			"SET" => 35,
			"(" => 16,
			"FOREACH" => 26,
			"FUNCTION" => 27,
			'name' => 19,
			'literal' => 18,
			"!" => 20,
			"MACRO" => 33
		},
		GOTOS => {
			'fn' => 21,
			'fn_def' => 29,
			'for' => 28,
			'p11' => 14,
			'p10' => 13,
			'c_for' => 22,
			'nonbrace' => 9,
			'code_chunk' => 32,
			'c_set' => 24,
			'c_fn' => 25,
			'exp' => 34,
			'c_if' => 36,
			'varref' => 15
		}
	},
	{#State 173
		DEFAULT => -16
	}
],
        yyrules =>
[
	[#Rule 0
		 '$start', 2, undef
	],
	[#Rule 1
		 'template', 1,
sub
#line 74 "template.yp"
{
    $_[0]->{functions}->{main}->{body} = "sub fn_main {\nmy \$self = shift;\nmy \$stack = [];\nmy \$t = '';\n".$_[1]."\nreturn \$t;\n}\n";
    '';
  }
	],
	[#Rule 2
		 'chunks', 0,
sub
#line 79 "template.yp"
{
    '';
  }
	],
	[#Rule 3
		 'chunks', 2,
sub
#line 82 "template.yp"
{
    $_[1] . $_[2];
  }
	],
	[#Rule 4
		 'chunk', 1,
sub
#line 86 "template.yp"
{
    '$t .= ' . $_[1][0] . ";\n";
  }
	],
	[#Rule 5
		 'chunk', 3,
sub
#line 89 "template.yp"
{
    $_[2];
  }
	],
	[#Rule 6
		 'chunk', 3,
sub
#line 92 "template.yp"
{
    '$t .= ' . ($_[2][1] || !$_[0]->{options}->{auto_escape} ? $_[2][0] : $_[0]->compile_function($_[0]->{options}->{auto_escape}, [ $_[2] ])->[0]) . ";\n";
  }
	],
	[#Rule 7
		 'chunk', 1,
sub
#line 95 "template.yp"
{
    '';
  }
	],
	[#Rule 8
		 'code_chunk', 1, undef
	],
	[#Rule 9
		 'code_chunk', 1, undef
	],
	[#Rule 10
		 'code_chunk', 1, undef
	],
	[#Rule 11
		 'code_chunk', 1, undef
	],
	[#Rule 12
		 'code_chunk', 1,
sub
#line 99 "template.yp"
{
    ($_[1][2] || !$_[0]->{options}->{no_code_subst} ? '$t .= ' : '') .
    ($_[1][1] || !$_[0]->{options}->{auto_escape} ? $_[1][0] : $_[0]->compile_function($_[0]->{options}->{auto_escape}, [ $_[1] ])->[0]) . ";\n";
  }
	],
	[#Rule 13
		 'c_if', 6,
sub
#line 104 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . "}\n";
  }
	],
	[#Rule 14
		 'c_if', 10,
sub
#line 107 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . "} else {\n" . $_[8] . "}\n";
  }
	],
	[#Rule 15
		 'c_if', 8,
sub
#line 110 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . $_[5] . $_[6] . "}\n";
  }
	],
	[#Rule 16
		 'c_if', 12,
sub
#line 113 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . $_[5] . $_[6] . "} else {\n" . $_[10] . "}\n";
  }
	],
	[#Rule 17
		 'c_elseifs', 4,
sub
#line 117 "template.yp"
{
    #{
    "} elsif (" . $_[3][0] . ") {\n";
    #}
  }
	],
	[#Rule 18
		 'c_elseifs', 6,
sub
#line 122 "template.yp"
{
    #{
    $_[1] . $_[2] . "} elsif (" . $_[5][0] . ") {\n";
    #}
  }
	],
	[#Rule 19
		 'c_set', 4,
sub
#line 128 "template.yp"
{
    $_[2][0] . ' = ' . $_[4][0] . ";\n";
  }
	],
	[#Rule 20
		 'c_set', 6,
sub
#line 131 "template.yp"
{
    "push \@\$stack, \$t;\n\$t = '';\n" . $_[4] . $_[2][0] . " = \$t;\n\$t = pop(\@\$stack);\n";
  }
	],
	[#Rule 21
		 'fn_def', 5,
sub
#line 135 "template.yp"
{
    $_[0]->{functions}->{$_[2]} = {
      name => $_[2],
      args => $_[4],
      line => $_[0]->{lexer}->line,
      pos => $_[0]->{lexer}->pos,
      body => 'sub fn_'.$_[2],
    };
  }
	],
	[#Rule 22
		 'c_fn', 3,
sub
#line 145 "template.yp"
{
    $_[1]->{body} .= " {\nmy \$self = shift;\nreturn ".$_[3].";\n}\n";
    '';
  }
	],
	[#Rule 23
		 'c_fn', 5,
sub
#line 149 "template.yp"
{
    $_[1]->{body} .= " {\nmy \$self = shift;\nmy \$stack = [];\nmy \$t = '';\n".$_[3]."\nreturn \$t;\n}\n";
    '';
  }
	],
	[#Rule 24
		 'c_for', 8,
sub
#line 154 "template.yp"
{
    my @varref = @{$_[2]};
    my @exp = @_{$_[4]};
    my $cs = $_[6];
    #{
    my $varref_index = substr($varref[0], 0, -1) . ".'_index'}";
    "push \@\$stack, ".$varref[0].", ".$varref_index.", 0;
foreach my \$item (array_items($exp[0])) {
".$varref[0]." = \$item;
".$varref_index." = \$stack->[\$#\$stack]++;
".$cs."}
pop \@\$stack;
".$varref_index." = pop(\@\$stack);
".$varref[0]." = pop(\@\$stack);
";
  }
	],
	[#Rule 25
		 'fn', 1, undef
	],
	[#Rule 26
		 'fn', 1, undef
	],
	[#Rule 27
		 'fn', 1, undef
	],
	[#Rule 28
		 'for', 1, undef
	],
	[#Rule 29
		 'for', 1, undef
	],
	[#Rule 30
		 'elseif', 2, undef
	],
	[#Rule 31
		 'elseif', 1, undef
	],
	[#Rule 32
		 'elseif', 1, undef
	],
	[#Rule 33
		 'exp', 3,
sub
#line 177 "template.yp"
{
    [ '(' . $_[1][0] . ' . ' . $_[3][0] . ')', $_[1][1] && $_[3][1] ];
  }
	],
	[#Rule 34
		 'exp', 3,
sub
#line 180 "template.yp"
{
    [ '(' . $_[1][0] . ' || ' . $_[3][0] . ')', $_[1][1] && $_[3][1] ];
  }
	],
	[#Rule 35
		 'exp', 3,
sub
#line 183 "template.yp"
{
    [ '(' . $_[1][0] . ' || ' . $_[3][0] . ')', $_[1][1] && $_[3][1] ];
  }
	],
	[#Rule 36
		 'exp', 3,
sub
#line 186 "template.yp"
{
    [ '(' . $_[1][0] . ' XOR ' . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 37
		 'exp', 3,
sub
#line 189 "template.yp"
{
    [ '(' . $_[1][0] . ' && ' . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 38
		 'exp', 3,
sub
#line 192 "template.yp"
{
    [ '(' . $_[1][0] . ' && ' . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 39
		 'exp', 3,
sub
#line 195 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' == ' : ' eq ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 40
		 'exp', 3,
sub
#line 198 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' != ' : ' ne ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 41
		 'exp', 3,
sub
#line 201 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' < ' : ' lt ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 42
		 'exp', 3,
sub
#line 204 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' > ' : ' gt ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 43
		 'exp', 3,
sub
#line 207 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' <= ' : ' le ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 44
		 'exp', 3,
sub
#line 210 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' >= ' : ' ge ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 45
		 'exp', 3,
sub
#line 213 "template.yp"
{
    [ '(' . $_[1][0] . ' + ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 46
		 'exp', 3,
sub
#line 216 "template.yp"
{
    [ '(' . $_[1][0] . ' - ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 47
		 'exp', 3,
sub
#line 219 "template.yp"
{
    [ '(' . $_[1][0] . ' & ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 48
		 'exp', 3,
sub
#line 222 "template.yp"
{
    [ '(' . $_[1][0] . ' * ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 49
		 'exp', 3,
sub
#line 225 "template.yp"
{
    [ '(' . $_[1][0] . ' / ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 50
		 'exp', 3,
sub
#line 228 "template.yp"
{
    [ '(' . $_[1][0] . ' % ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 51
		 'exp', 1, undef
	],
	[#Rule 52
		 'p10', 1, undef
	],
	[#Rule 53
		 'p10', 2,
sub
#line 234 "template.yp"
{
    [ '(-'.$_[2][0].')', 1 ];
  }
	],
	[#Rule 54
		 'p11', 1, undef
	],
	[#Rule 55
		 'p11', 4,
sub
#line 239 "template.yp"
{
    [ '('.$_[2][0].')'.$_[4], 0 ];
  }
	],
	[#Rule 56
		 'p11', 2,
sub
#line 242 "template.yp"
{
    [ '(!'.$_[2][0].')', 1 ];
  }
	],
	[#Rule 57
		 'p11', 2,
sub
#line 245 "template.yp"
{
    [ '(!'.$_[2][0].')', 1 ];
  }
	],
	[#Rule 58
		 'nonbrace', 3,
sub
#line 249 "template.yp"
{
    [ "{ " . $_[2] . " }", 1 ];
  }
	],
	[#Rule 59
		 'nonbrace', 1, undef
	],
	[#Rule 60
		 'nonbrace', 1, undef
	],
	[#Rule 61
		 'nonbrace', 3,
sub
#line 254 "template.yp"
{
    $_[0]->compile_function($_[1], []);
  }
	],
	[#Rule 62
		 'nonbrace', 4,
sub
#line 257 "template.yp"
{
    $_[0]->compile_function($_[1], $_[3]);
  }
	],
	[#Rule 63
		 'nonbrace', 4,
sub
#line 260 "template.yp"
{
    [ "\$self->{template}->call_block('".addcslashes($_[1], "'")."', { ".$_[3]." }, '".addcslashes($_[0]->{lexer}->errorinfo(), "'")."')", 1 ];
  }
	],
	[#Rule 64
		 'nonbrace', 2,
sub
#line 263 "template.yp"
{
    $_[0]->compile_function($_[1], [ $_[2] ]);
  }
	],
	[#Rule 65
		 'list', 1,
sub
#line 267 "template.yp"
{
    [ $_[1] ];
  }
	],
	[#Rule 66
		 'list', 3,
sub
#line 270 "template.yp"
{
    [ $_[1], @{$_[3]} ];
  }
	],
	[#Rule 67
		 'arglist', 1,
sub
#line 274 "template.yp"
{
    [ $_[1] ];
  }
	],
	[#Rule 68
		 'arglist', 3,
sub
#line 277 "template.yp"
{
    [ $_[1], @{$_[3]} ];
  }
	],
	[#Rule 69
		 'arglist', 0,
sub
#line 280 "template.yp"
{
    [];
  }
	],
	[#Rule 70
		 'hash', 1, undef
	],
	[#Rule 71
		 'hash', 3,
sub
#line 285 "template.yp"
{
    $_[1] . ', ' . $_[3];
  }
	],
	[#Rule 72
		 'hash', 0,
sub
#line 288 "template.yp"
{
    '';
  }
	],
	[#Rule 73
		 'gthash', 1, undef
	],
	[#Rule 74
		 'gthash', 3,
sub
#line 293 "template.yp"
{
    $_[1] . ', ' . $_[3];
  }
	],
	[#Rule 75
		 'pair', 3,
sub
#line 297 "template.yp"
{
    $_[1][0] . ' => ' . $_[3][0];
  }
	],
	[#Rule 76
		 'pair', 1, undef
	],
	[#Rule 77
		 'gtpair', 3,
sub
#line 302 "template.yp"
{
    $_[1][0] . ' => ' . $_[3][0];
  }
	],
	[#Rule 78
		 'varref', 1,
sub
#line 306 "template.yp"
{
    [ "\$self->{tpldata}{'".addcslashes($_[1], "'")."'}", 0 ];
  }
	],
	[#Rule 79
		 'varref', 2,
sub
#line 309 "template.yp"
{
    [ $_[1][0] . $_[2], 0 ];
  }
	],
	[#Rule 80
		 'varpart', 2,
sub
#line 313 "template.yp"
{
    "{'".addcslashes($_[2], "'")."'}";
  }
	],
	[#Rule 81
		 'varpart', 3,
sub
#line 316 "template.yp"
{
    ($_[2][1] eq 'i' ? '['.$_[2][0].']' : "{".$_[2][0]."}");
  }
	],
	[#Rule 82
		 'varpart', 4,
sub
#line 319 "template.yp"
{
    '->'.$_[2].'()';
  }
	],
	[#Rule 83
		 'varpart', 5,
sub
#line 322 "template.yp"
{
    '->'.$_[2].'('.join(', ', map { $_->[0] } @{$_[4]}).')';
  }
	],
	[#Rule 84
		 'varpath', 0,
sub
#line 326 "template.yp"
{
    '';
  }
	],
	[#Rule 85
		 'varpath', 2,
sub
#line 329 "template.yp"
{
    $_[1] . $_[2];
  }
	]
],
#line 29 "template.skel.pm"
    ), $class;
    $self->{options} = $options;
    return $self;
}

1;
