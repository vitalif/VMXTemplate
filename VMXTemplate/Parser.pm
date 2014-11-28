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
			'chunks' => 1,
			'template' => 2
		}
	},
	{#State 1
		ACTIONS => {
			'' => -1,
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 7
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 2
		ACTIONS => {
			'' => 8
		}
	},
	{#State 3
		DEFAULT => -5
	},
	{#State 4
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"!" => 18,
			"(" => 17,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'varref' => 14,
			'exp' => 10,
			'p11' => 16,
			'p10' => 19,
			'nonbrace' => 11
		}
	},
	{#State 5
		DEFAULT => -3
	},
	{#State 6
		DEFAULT => -4
	},
	{#State 7
		ACTIONS => {
			"SET" => 30,
			"-" => 9,
			"MACRO" => 21,
			"{" => 13,
			'name' => 12,
			"BLOCK" => 22,
			"IF" => 32,
			'literal' => 15,
			"(" => 17,
			"!" => 18,
			"FOR" => 33,
			"NOT" => 20,
			"FOREACH" => 27,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 8
		DEFAULT => 0
	},
	{#State 9
		ACTIONS => {
			'literal' => 15,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'varref' => 14,
			'p11' => 37,
			'nonbrace' => 11
		}
	},
	{#State 10
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"}}" => 46,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 11
		DEFAULT => -54
	},
	{#State 12
		ACTIONS => {
			'literal' => 15,
			'name' => 12,
			"(" => 58,
			"{" => 13
		},
		DEFAULT => -78,
		GOTOS => {
			'varref' => 14,
			'nonbrace' => 57
		}
	},
	{#State 13
		ACTIONS => {
			"-" => 9,
			"{" => 13,
			'name' => 12,
			'literal' => 15,
			"!" => 18,
			"(" => 17,
			"NOT" => 20
		},
		DEFAULT => -72,
		GOTOS => {
			'exp' => 60,
			'nonbrace' => 11,
			'gtpair' => 61,
			'varref' => 14,
			'hash' => 62,
			'p11' => 16,
			'pair' => 59,
			'p10' => 19
		}
	},
	{#State 14
		ACTIONS => {
			"[" => 63,
			"." => 64
		},
		DEFAULT => -60,
		GOTOS => {
			'varpart' => 65
		}
	},
	{#State 15
		DEFAULT => -59
	},
	{#State 16
		DEFAULT => -52
	},
	{#State 17
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 66,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 18
		ACTIONS => {
			'literal' => 15,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'varref' => 14,
			'p11' => 67,
			'nonbrace' => 11
		}
	},
	{#State 19
		DEFAULT => -51
	},
	{#State 20
		ACTIONS => {
			'literal' => 15,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'varref' => 14,
			'p11' => 68,
			'nonbrace' => 11
		}
	},
	{#State 21
		DEFAULT => -27
	},
	{#State 22
		DEFAULT => -26
	},
	{#State 23
		ACTIONS => {
			"-->" => 69
		}
	},
	{#State 24
		DEFAULT => -9
	},
	{#State 25
		DEFAULT => -8
	},
	{#State 26
		ACTIONS => {
			"-->" => 70,
			"=" => 71
		}
	},
	{#State 27
		DEFAULT => -29
	},
	{#State 28
		ACTIONS => {
			'name' => 72
		}
	},
	{#State 29
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -12
	},
	{#State 30
		ACTIONS => {
			'name' => 74
		},
		GOTOS => {
			'varref' => 73
		}
	},
	{#State 31
		ACTIONS => {
			'name' => 74
		},
		GOTOS => {
			'varref' => 75
		}
	},
	{#State 32
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 76,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 33
		DEFAULT => -28
	},
	{#State 34
		DEFAULT => -11
	},
	{#State 35
		DEFAULT => -10
	},
	{#State 36
		DEFAULT => -25
	},
	{#State 37
		DEFAULT => -53
	},
	{#State 38
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 77,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 39
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 78,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 40
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 79,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 41
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 80,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 42
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 81,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 43
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 82,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 44
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 83,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 45
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 84,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 46
		DEFAULT => -7
	},
	{#State 47
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 85,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 48
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 86,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 49
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 87,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 50
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 88,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 51
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 89,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 52
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 90,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 53
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 91,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 54
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 92,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 55
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 93,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 56
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 94,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 57
		DEFAULT => -64
	},
	{#State 58
		ACTIONS => {
			"-" => 9,
			"{" => 13,
			'name' => 12,
			'literal' => 15,
			"!" => 18,
			"(" => 17,
			"NOT" => 20,
			")" => 95
		},
		GOTOS => {
			'exp' => 97,
			'nonbrace' => 11,
			'gtpair' => 98,
			'varref' => 14,
			'p11' => 16,
			'p10' => 19,
			'gthash' => 99,
			'list' => 96
		}
	},
	{#State 59
		ACTIONS => {
			"," => 100
		},
		DEFAULT => -70
	},
	{#State 60
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"," => 101,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"=>" => 102,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 61
		DEFAULT => -76
	},
	{#State 62
		ACTIONS => {
			"}" => 103
		}
	},
	{#State 63
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 104,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 64
		ACTIONS => {
			'name' => 105
		}
	},
	{#State 65
		DEFAULT => -79
	},
	{#State 66
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			")" => 106,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 67
		DEFAULT => -56
	},
	{#State 68
		DEFAULT => -57
	},
	{#State 69
		DEFAULT => -6
	},
	{#State 70
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 107
		}
	},
	{#State 71
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 108,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 72
		ACTIONS => {
			"(" => 109
		}
	},
	{#State 73
		ACTIONS => {
			"-->" => 110,
			"[" => 63,
			"." => 64,
			"=" => 111
		},
		GOTOS => {
			'varpart' => 65
		}
	},
	{#State 74
		DEFAULT => -78
	},
	{#State 75
		ACTIONS => {
			"[" => 63,
			"." => 64,
			"=" => 112
		},
		GOTOS => {
			'varpart' => 65
		}
	},
	{#State 76
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"-->" => 113,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 77
		ACTIONS => {
			"%" => 43,
			"*" => 47,
			"&" => 52,
			"/" => 53
		},
		DEFAULT => -46
	},
	{#State 78
		ACTIONS => {
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -33
	},
	{#State 79
		ACTIONS => {
			"-" => 38,
			"<" => undef,
			"+" => 42,
			"%" => 43,
			"==" => undef,
			">=" => undef,
			"*" => 47,
			"!=" => undef,
			"&" => 52,
			"/" => 53,
			"<=" => undef,
			">" => undef
		},
		DEFAULT => -41
	},
	{#State 80
		ACTIONS => {
			"-" => 38,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"&" => 52,
			"/" => 53,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -35
	},
	{#State 81
		ACTIONS => {
			"%" => 43,
			"*" => 47,
			"&" => 52,
			"/" => 53
		},
		DEFAULT => -45
	},
	{#State 82
		DEFAULT => -50
	},
	{#State 83
		ACTIONS => {
			"-" => 38,
			"<" => undef,
			"+" => 42,
			"%" => 43,
			"==" => undef,
			">=" => undef,
			"*" => 47,
			"!=" => undef,
			"&" => 52,
			"/" => 53,
			"<=" => undef,
			">" => undef
		},
		DEFAULT => -39
	},
	{#State 84
		ACTIONS => {
			"-" => 38,
			"<" => undef,
			"+" => 42,
			"%" => 43,
			"==" => undef,
			">=" => undef,
			"*" => 47,
			"!=" => undef,
			"&" => 52,
			"/" => 53,
			"<=" => undef,
			">" => undef
		},
		DEFAULT => -44
	},
	{#State 85
		DEFAULT => -48
	},
	{#State 86
		ACTIONS => {
			"-" => 38,
			"<" => undef,
			"+" => 42,
			"%" => 43,
			"==" => undef,
			">=" => undef,
			"*" => 47,
			"!=" => undef,
			"&" => 52,
			"/" => 53,
			"<=" => undef,
			">" => undef
		},
		DEFAULT => -40
	},
	{#State 87
		ACTIONS => {
			"-" => 38,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"&" => 52,
			"/" => 53,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -38
	},
	{#State 88
		ACTIONS => {
			"-" => 38,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"&" => 52,
			"/" => 53,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -37
	},
	{#State 89
		ACTIONS => {
			"-" => 38,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"&" => 52,
			"/" => 53,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -34
	},
	{#State 90
		ACTIONS => {
			"%" => 43,
			"*" => 47,
			"/" => 53
		},
		DEFAULT => -47
	},
	{#State 91
		DEFAULT => -49
	},
	{#State 92
		ACTIONS => {
			"-" => 38,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"&" => 52,
			"/" => 53,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -36
	},
	{#State 93
		ACTIONS => {
			"-" => 38,
			"<" => undef,
			"+" => 42,
			"%" => 43,
			"==" => undef,
			">=" => undef,
			"*" => 47,
			"!=" => undef,
			"&" => 52,
			"/" => 53,
			"<=" => undef,
			">" => undef
		},
		DEFAULT => -43
	},
	{#State 94
		ACTIONS => {
			"-" => 38,
			"<" => undef,
			"+" => 42,
			"%" => 43,
			"==" => undef,
			">=" => undef,
			"*" => 47,
			"!=" => undef,
			"&" => 52,
			"/" => 53,
			"<=" => undef,
			">" => undef
		},
		DEFAULT => -42
	},
	{#State 95
		DEFAULT => -61
	},
	{#State 96
		ACTIONS => {
			")" => 114
		}
	},
	{#State 97
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"," => 115,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"=>" => 102,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -65
	},
	{#State 98
		ACTIONS => {
			"," => 116
		},
		DEFAULT => -73
	},
	{#State 99
		ACTIONS => {
			")" => 117
		}
	},
	{#State 100
		ACTIONS => {
			"-" => 9,
			"{" => 13,
			'name' => 12,
			'literal' => 15,
			"!" => 18,
			"(" => 17,
			"NOT" => 20
		},
		DEFAULT => -72,
		GOTOS => {
			'exp' => 60,
			'nonbrace' => 11,
			'gtpair' => 61,
			'varref' => 14,
			'hash' => 118,
			'p11' => 16,
			'pair' => 59,
			'p10' => 19
		}
	},
	{#State 101
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 119,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 102
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 120,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 103
		DEFAULT => -58
	},
	{#State 104
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"]" => 121,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 105
		ACTIONS => {
			"(" => 122
		},
		DEFAULT => -80
	},
	{#State 106
		DEFAULT => -84,
		GOTOS => {
			'varpath' => 123
		}
	},
	{#State 107
		ACTIONS => {
			'literal' => 3,
			"{{" => 4,
			'error' => 5,
			"<!--" => 124
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 108
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -22
	},
	{#State 109
		ACTIONS => {
			'name' => 125
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 126
		}
	},
	{#State 110
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 127
		}
	},
	{#State 111
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 128,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 112
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 129,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 113
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 130
		}
	},
	{#State 114
		DEFAULT => -62
	},
	{#State 115
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 132,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19,
			'list' => 131
		}
	},
	{#State 116
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'exp' => 133,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'gtpair' => 98,
			'p10' => 19,
			'gthash' => 134
		}
	},
	{#State 117
		DEFAULT => -63
	},
	{#State 118
		DEFAULT => -71
	},
	{#State 119
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -75
	},
	{#State 120
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -77
	},
	{#State 121
		DEFAULT => -81
	},
	{#State 122
		ACTIONS => {
			"-" => 9,
			"{" => 13,
			'name' => 12,
			'literal' => 15,
			"!" => 18,
			"(" => 17,
			"NOT" => 20,
			")" => 135
		},
		GOTOS => {
			'exp' => 132,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19,
			'list' => 136
		}
	},
	{#State 123
		ACTIONS => {
			"[" => 63,
			"." => 64
		},
		DEFAULT => -55,
		GOTOS => {
			'varpart' => 137
		}
	},
	{#State 124
		ACTIONS => {
			"END" => 138,
			"SET" => 30,
			"-" => 9,
			"MACRO" => 21,
			"{" => 13,
			'name' => 12,
			"BLOCK" => 22,
			"IF" => 32,
			'literal' => 15,
			"(" => 17,
			"!" => 18,
			"FOR" => 33,
			"NOT" => 20,
			"FOREACH" => 27,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'c_fn' => 35,
			'fn' => 28
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
			")" => 140
		}
	},
	{#State 127
		ACTIONS => {
			'literal' => 3,
			"{{" => 4,
			'error' => 5,
			"<!--" => 141
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 128
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -19
	},
	{#State 129
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"-->" => 142,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 130
		ACTIONS => {
			'literal' => 3,
			"{{" => 4,
			'error' => 5,
			"<!--" => 144
		},
		GOTOS => {
			'c_elseifs' => 143,
			'chunk' => 6
		}
	},
	{#State 131
		DEFAULT => -66
	},
	{#State 132
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"," => 115,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		},
		DEFAULT => -65
	},
	{#State 133
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"&&" => 50,
			"||" => 51,
			"&" => 52,
			"/" => 53,
			"XOR" => 54,
			"=>" => 102,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 134
		DEFAULT => -74
	},
	{#State 135
		DEFAULT => -82
	},
	{#State 136
		ACTIONS => {
			")" => 145
		}
	},
	{#State 137
		DEFAULT => -85
	},
	{#State 138
		DEFAULT => -23
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
		DEFAULT => -21
	},
	{#State 141
		ACTIONS => {
			"END" => 147,
			"SET" => 30,
			"-" => 9,
			"MACRO" => 21,
			"{" => 13,
			'name' => 12,
			"BLOCK" => 22,
			"IF" => 32,
			'literal' => 15,
			"(" => 17,
			"!" => 18,
			"FOR" => 33,
			"NOT" => 20,
			"FOREACH" => 27,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 142
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 148
		}
	},
	{#State 143
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 149
		}
	},
	{#State 144
		ACTIONS => {
			"-" => 9,
			"MACRO" => 21,
			"BLOCK" => 22,
			"ELSIF" => 150,
			'literal' => 15,
			"!" => 18,
			"FOREACH" => 27,
			"ELSE" => 153,
			"END" => 151,
			"SET" => 30,
			"{" => 13,
			'name' => 12,
			"ELSEIF" => 152,
			"IF" => 32,
			"(" => 17,
			"FOR" => 33,
			"NOT" => 20,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'elseif' => 154,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 145
		DEFAULT => -83
	},
	{#State 146
		DEFAULT => -68
	},
	{#State 147
		DEFAULT => -20
	},
	{#State 148
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 155
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 149
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 156
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 150
		DEFAULT => -31
	},
	{#State 151
		DEFAULT => -13
	},
	{#State 152
		DEFAULT => -32
	},
	{#State 153
		ACTIONS => {
			"IF" => 157,
			"-->" => 158
		}
	},
	{#State 154
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'varref' => 14,
			'exp' => 159,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 155
		ACTIONS => {
			"SET" => 30,
			"END" => 160,
			"-" => 9,
			"MACRO" => 21,
			"{" => 13,
			'name' => 12,
			"BLOCK" => 22,
			'literal' => 15,
			"IF" => 32,
			"(" => 17,
			"!" => 18,
			"FOR" => 33,
			"NOT" => 20,
			"FOREACH" => 27,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 156
		ACTIONS => {
			"-" => 9,
			"MACRO" => 21,
			"BLOCK" => 22,
			"ELSIF" => 150,
			'literal' => 15,
			"!" => 18,
			"ELSE" => 162,
			"FOREACH" => 27,
			"END" => 161,
			"SET" => 30,
			"{" => 13,
			'name' => 12,
			"ELSEIF" => 152,
			"IF" => 32,
			"(" => 17,
			"FOR" => 33,
			"NOT" => 20,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'elseif' => 163,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 157
		DEFAULT => -30
	},
	{#State 158
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 164
		}
	},
	{#State 159
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"||" => 51,
			"&&" => 50,
			"&" => 52,
			"-->" => 165,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 160
		DEFAULT => -24
	},
	{#State 161
		DEFAULT => -15
	},
	{#State 162
		ACTIONS => {
			"IF" => 157,
			"-->" => 166
		}
	},
	{#State 163
		ACTIONS => {
			'literal' => 15,
			"-" => 9,
			"(" => 17,
			"!" => 18,
			"NOT" => 20,
			"{" => 13,
			'name' => 12
		},
		GOTOS => {
			'varref' => 14,
			'exp' => 167,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 164
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 168
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 165
		DEFAULT => -17
	},
	{#State 166
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 169
		}
	},
	{#State 167
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"==" => 44,
			">=" => 45,
			"*" => 47,
			"!=" => 48,
			"AND" => 49,
			"||" => 51,
			"&&" => 50,
			"&" => 52,
			"-->" => 170,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 168
		ACTIONS => {
			"SET" => 30,
			"END" => 171,
			"-" => 9,
			"MACRO" => 21,
			"{" => 13,
			'name' => 12,
			"BLOCK" => 22,
			'literal' => 15,
			"IF" => 32,
			"(" => 17,
			"!" => 18,
			"FOR" => 33,
			"NOT" => 20,
			"FOREACH" => 27,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 169
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 172
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 170
		DEFAULT => -18
	},
	{#State 171
		DEFAULT => -14
	},
	{#State 172
		ACTIONS => {
			"SET" => 30,
			"END" => 173,
			"-" => 9,
			"MACRO" => 21,
			"{" => 13,
			'name' => 12,
			"BLOCK" => 22,
			'literal' => 15,
			"IF" => 32,
			"(" => 17,
			"!" => 18,
			"FOR" => 33,
			"NOT" => 20,
			"FOREACH" => 27,
			"FUNCTION" => 36
		},
		GOTOS => {
			'exp' => 29,
			'nonbrace' => 11,
			'for' => 31,
			'code_chunk' => 23,
			'varref' => 14,
			'p11' => 16,
			'c_set' => 24,
			'p10' => 19,
			'c_if' => 25,
			'fn_def' => 26,
			'c_for' => 34,
			'c_fn' => 35,
			'fn' => 28
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
    $_[0]->{functions}->{':main'}->{body} = "sub {\nmy \$self = shift;\nmy \$stack = [];\nmy \$t = '';\n".$_[1]."\nreturn \$t;\n}\n";
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
    # Exit error recovery
    $_[0]->YYErrok;
    # Skip current token
    ${$_[0]->{TOKEN}} = undef;
    $_[1];
  }
	],
	[#Rule 4
		 'chunks', 2,
sub
#line 89 "template.yp"
{
    $_[1] .
    '# line '.(1+$_[0]->{lexer}->{lineno}).' "'.$_[0]->{options}->{input_filename}."\"\n".
    $_[2];
  }
	],
	[#Rule 5
		 'chunk', 1,
sub
#line 95 "template.yp"
{
    '$t .= ' . $_[1][0] . ";\n";
  }
	],
	[#Rule 6
		 'chunk', 3,
sub
#line 98 "template.yp"
{
    $_[2];
  }
	],
	[#Rule 7
		 'chunk', 3,
sub
#line 101 "template.yp"
{
    '$t .= ' . ($_[2][1] || !$_[0]->{options}->{auto_escape} ? $_[2][0] : $_[0]->compile_function($_[0]->{options}->{auto_escape}, [ $_[2] ])->[0]) . ";\n";
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
#line 105 "template.yp"
{
    ($_[1][2] || !$_[0]->{options}->{no_code_subst} ? '$t .= ' : '') .
    ($_[1][1] || !$_[0]->{options}->{auto_escape} ? $_[1][0] : $_[0]->compile_function($_[0]->{options}->{auto_escape}, [ $_[1] ])->[0]) . ";\n";
  }
	],
	[#Rule 13
		 'c_if', 6,
sub
#line 110 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . "}\n";
  }
	],
	[#Rule 14
		 'c_if', 10,
sub
#line 113 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . "} else {\n" . $_[8] . "}\n";
  }
	],
	[#Rule 15
		 'c_if', 8,
sub
#line 116 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . $_[5] . $_[6] . "}\n";
  }
	],
	[#Rule 16
		 'c_if', 12,
sub
#line 119 "template.yp"
{
    "if (" . $_[2][0] . ") {\n" . $_[4] . $_[5] . $_[6] . "} else {\n" . $_[10] . "}\n";
  }
	],
	[#Rule 17
		 'c_elseifs', 4,
sub
#line 123 "template.yp"
{
    #{
    "} elsif (" . $_[3][0] . ") {\n";
    #}
  }
	],
	[#Rule 18
		 'c_elseifs', 6,
sub
#line 128 "template.yp"
{
    #{
    $_[1] . $_[2] . "} elsif (" . $_[5][0] . ") {\n";
    #}
  }
	],
	[#Rule 19
		 'c_set', 4,
sub
#line 134 "template.yp"
{
    $_[2][0] . ' = ' . $_[4][0] . ";\n";
  }
	],
	[#Rule 20
		 'c_set', 6,
sub
#line 137 "template.yp"
{
    "push \@\$stack, \$t;\n\$t = '';\n" . $_[4] . $_[2][0] . " = \$t;\n\$t = pop(\@\$stack);\n";
  }
	],
	[#Rule 21
		 'fn_def', 5,
sub
#line 141 "template.yp"
{
    $_[0]->{functions}->{$_[2]} = {
      name => $_[2],
      args => $_[4],
      line => $_[0]->{lexer}->line,
      pos => $_[0]->{lexer}->pos,
      body => '',
    };
  }
	],
	[#Rule 22
		 'c_fn', 3,
sub
#line 151 "template.yp"
{
    $_[1]->{body} = "sub {\nmy \$self = shift;\nreturn ".$_[3].";\n}\n";
    '';
  }
	],
	[#Rule 23
		 'c_fn', 5,
sub
#line 155 "template.yp"
{
    $_[1]->{body} = "sub {\nmy \$self = shift;\nmy \$stack = [];\nmy \$t = '';\n".$_[3]."\nreturn \$t;\n}\n";
    '';
  }
	],
	[#Rule 24
		 'c_for', 8,
sub
#line 160 "template.yp"
{
    my @varref = @{$_[2]};
    my @exp = @{$_[4]};
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
#line 183 "template.yp"
{
    [ '(' . $_[1][0] . ' . ' . $_[3][0] . ')', $_[1][1] && $_[3][1] ];
  }
	],
	[#Rule 34
		 'exp', 3,
sub
#line 186 "template.yp"
{
    [ '(' . $_[1][0] . ' || ' . $_[3][0] . ')', $_[1][1] && $_[3][1] ];
  }
	],
	[#Rule 35
		 'exp', 3,
sub
#line 189 "template.yp"
{
    [ '(' . $_[1][0] . ' || ' . $_[3][0] . ')', $_[1][1] && $_[3][1] ];
  }
	],
	[#Rule 36
		 'exp', 3,
sub
#line 192 "template.yp"
{
    [ '(' . $_[1][0] . ' XOR ' . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 37
		 'exp', 3,
sub
#line 195 "template.yp"
{
    [ '(' . $_[1][0] . ' && ' . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 38
		 'exp', 3,
sub
#line 198 "template.yp"
{
    [ '(' . $_[1][0] . ' && ' . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 39
		 'exp', 3,
sub
#line 201 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' == ' : ' eq ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 40
		 'exp', 3,
sub
#line 204 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' != ' : ' ne ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 41
		 'exp', 3,
sub
#line 207 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' < ' : ' lt ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 42
		 'exp', 3,
sub
#line 210 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' > ' : ' gt ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 43
		 'exp', 3,
sub
#line 213 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' <= ' : ' le ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 44
		 'exp', 3,
sub
#line 216 "template.yp"
{
    [ '(' . $_[1][0] . ($_[1][1] eq 'i' || $_[3][1] eq 'i' ? ' >= ' : ' ge ') . $_[3][0] . ')', 1 ];
  }
	],
	[#Rule 45
		 'exp', 3,
sub
#line 219 "template.yp"
{
    [ '(' . $_[1][0] . ' + ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 46
		 'exp', 3,
sub
#line 222 "template.yp"
{
    [ '(' . $_[1][0] . ' - ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 47
		 'exp', 3,
sub
#line 225 "template.yp"
{
    [ '(' . $_[1][0] . ' & ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 48
		 'exp', 3,
sub
#line 228 "template.yp"
{
    [ '(' . $_[1][0] . ' * ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 49
		 'exp', 3,
sub
#line 231 "template.yp"
{
    [ '(' . $_[1][0] . ' / ' . $_[3][0] . ')', 'i' ];
  }
	],
	[#Rule 50
		 'exp', 3,
sub
#line 234 "template.yp"
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
#line 240 "template.yp"
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
#line 245 "template.yp"
{
    [ '('.$_[2][0].')'.$_[4], 0 ];
  }
	],
	[#Rule 56
		 'p11', 2,
sub
#line 248 "template.yp"
{
    [ '(!'.$_[2][0].')', 1 ];
  }
	],
	[#Rule 57
		 'p11', 2,
sub
#line 251 "template.yp"
{
    [ '(!'.$_[2][0].')', 1 ];
  }
	],
	[#Rule 58
		 'nonbrace', 3,
sub
#line 255 "template.yp"
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
#line 260 "template.yp"
{
    $_[0]->compile_function($_[1], []);
  }
	],
	[#Rule 62
		 'nonbrace', 4,
sub
#line 263 "template.yp"
{
    $_[0]->compile_function($_[1], $_[3]);
  }
	],
	[#Rule 63
		 'nonbrace', 4,
sub
#line 266 "template.yp"
{
    [ "\$self->_call_block('".addcslashes($_[1], "'")."', { ".$_[3]." }, '".addcslashes($_[0]->{lexer}->errorinfo(), "'")."')", 1 ];
  }
	],
	[#Rule 64
		 'nonbrace', 2,
sub
#line 269 "template.yp"
{
    $_[0]->compile_function($_[1], [ $_[2] ]);
  }
	],
	[#Rule 65
		 'list', 1,
sub
#line 273 "template.yp"
{
    [ $_[1] ];
  }
	],
	[#Rule 66
		 'list', 3,
sub
#line 276 "template.yp"
{
    [ $_[1], @{$_[3]} ];
  }
	],
	[#Rule 67
		 'arglist', 1,
sub
#line 280 "template.yp"
{
    [ $_[1] ];
  }
	],
	[#Rule 68
		 'arglist', 3,
sub
#line 283 "template.yp"
{
    [ $_[1], @{$_[3]} ];
  }
	],
	[#Rule 69
		 'arglist', 0,
sub
#line 286 "template.yp"
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
#line 291 "template.yp"
{
    $_[1] . ', ' . $_[3];
  }
	],
	[#Rule 72
		 'hash', 0,
sub
#line 294 "template.yp"
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
#line 299 "template.yp"
{
    $_[1] . ', ' . $_[3];
  }
	],
	[#Rule 75
		 'pair', 3,
sub
#line 303 "template.yp"
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
#line 308 "template.yp"
{
    $_[1][0] . ' => ' . $_[3][0];
  }
	],
	[#Rule 78
		 'varref', 1,
sub
#line 312 "template.yp"
{
    [ "\$self->{tpldata}{'".addcslashes($_[1], "'")."'}", 0 ];
  }
	],
	[#Rule 79
		 'varref', 2,
sub
#line 315 "template.yp"
{
    [ $_[1][0] . $_[2], 0 ];
  }
	],
	[#Rule 80
		 'varpart', 2,
sub
#line 319 "template.yp"
{
    "->{'".addcslashes($_[2], "'")."'}";
  }
	],
	[#Rule 81
		 'varpart', 3,
sub
#line 322 "template.yp"
{
    ($_[2][1] eq 'i' ? '->['.$_[2][0].']' : "->{".$_[2][0]."}");
  }
	],
	[#Rule 82
		 'varpart', 4,
sub
#line 325 "template.yp"
{
    '->'.$_[2].'()';
  }
	],
	[#Rule 83
		 'varpart', 5,
sub
#line 328 "template.yp"
{
    '->'.$_[2].'('.join(', ', map { $_->[0] } @{$_[4]}).')';
  }
	],
	[#Rule 84
		 'varpath', 0,
sub
#line 332 "template.yp"
{
    '';
  }
	],
	[#Rule 85
		 'varpath', 2,
sub
#line 335 "template.yp"
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
