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
use VMXTemplate::Compiler;
use VMXTemplate::Utils;
#Included Parse/Yapp/Driver.pm file----------------------------------------
{
#
# Module Parse::Yapp::Driver
#
# This module is part of the Parse::Yapp package available on your
# nearest CPAN
#
# Any use of this module in a standalone parser make the included
# text under the same copyright as the Parse::Yapp module itself.
#
# This notice should remain unchanged.
#
# (c) Copyright 1998-2001 Francois Desarmenien, all rights reserved.
# (see the pod text in Parse::Yapp module for use and distribution rights)
#

package Parse::Yapp::Driver;

require 5.004;

use strict;

use vars qw ( $VERSION $COMPATIBLE $FILENAME );

$VERSION = '1.05';
$COMPATIBLE = '0.07';
$FILENAME=__FILE__;

use Carp;

#Known parameters, all starting with YY (leading YY will be discarded)
my(%params)=(YYLEX => 'CODE', 'YYERROR' => 'CODE', YYVERSION => '',
			 YYRULES => 'ARRAY', YYSTATES => 'ARRAY', YYDEBUG => '');
#Mandatory parameters
my(@params)=('LEX','RULES','STATES');

sub new {
    my($class)=shift;
	my($errst,$nberr,$token,$value,$check,$dotpos);
    my($self)={ ERROR => \&_Error,
				ERRST => \$errst,
                NBERR => \$nberr,
				TOKEN => \$token,
				VALUE => \$value,
				DOTPOS => \$dotpos,
				STACK => [],
				DEBUG => 0,
				CHECK => \$check };

	_CheckParams( [], \%params, \@_, $self );

		exists($$self{VERSION})
	and	$$self{VERSION} < $COMPATIBLE
	and	croak "Yapp driver version $VERSION ".
			  "incompatible with version $$self{VERSION}:\n".
			  "Please recompile parser module.";

        ref($class)
    and $class=ref($class);

    bless($self,$class);
}

sub YYParse {
    my($self)=shift;
    my($retval);

	_CheckParams( \@params, \%params, \@_, $self );

	if($$self{DEBUG}) {
		_DBLoad();
		$retval = eval '$self->_DBParse()';#Do not create stab entry on compile
        $@ and die $@;
	}
	else {
		$retval = $self->_Parse();
	}
    $retval
}

sub YYData {
	my($self)=shift;

		exists($$self{USER})
	or	$$self{USER}={};

	$$self{USER};
	
}

sub YYErrok {
	my($self)=shift;

	${$$self{ERRST}}=0;
    undef;
}

sub YYNberr {
	my($self)=shift;

	${$$self{NBERR}};
}

sub YYRecovering {
	my($self)=shift;

	${$$self{ERRST}} != 0;
}

sub YYAbort {
	my($self)=shift;

	${$$self{CHECK}}='ABORT';
    undef;
}

sub YYAccept {
	my($self)=shift;

	${$$self{CHECK}}='ACCEPT';
    undef;
}

sub YYError {
	my($self)=shift;

	${$$self{CHECK}}='ERROR';
    undef;
}

sub YYSemval {
	my($self)=shift;
	my($index)= $_[0] - ${$$self{DOTPOS}} - 1;

		$index < 0
	and	-$index <= @{$$self{STACK}}
	and	return $$self{STACK}[$index][1];

	undef;	#Invalid index
}

sub YYCurtok {
	my($self)=shift;

        @_
    and ${$$self{TOKEN}}=$_[0];
    ${$$self{TOKEN}};
}

sub YYCurval {
	my($self)=shift;

        @_
    and ${$$self{VALUE}}=$_[0];
    ${$$self{VALUE}};
}

sub YYExpect {
    my($self)=shift;

    keys %{$self->{STATES}[$self->{STACK}[-1][0]]{ACTIONS}}
}

sub YYLexer {
    my($self)=shift;

	$$self{LEX};
}


#################
# Private stuff #
#################


sub _CheckParams {
	my($mandatory,$checklist,$inarray,$outhash)=@_;
	my($prm,$value);
	my($prmlst)={};

	while(($prm,$value)=splice(@$inarray,0,2)) {
        $prm=uc($prm);
			exists($$checklist{$prm})
		or	croak("Unknow parameter '$prm'");
			ref($value) eq $$checklist{$prm}
		or	croak("Invalid value for parameter '$prm'");
        $prm=unpack('@2A*',$prm);
		$$outhash{$prm}=$value;
	}
	for (@$mandatory) {
			exists($$outhash{$_})
		or	croak("Missing mandatory parameter '".lc($_)."'");
	}
}

sub _Error {
	print "Parse error.\n";
}

sub _DBLoad {
	{
		no strict 'refs';

			exists(${__PACKAGE__.'::'}{_DBParse})#Already loaded ?
		and	return;
	}
	my($fname)=__FILE__;
	my(@drv);
	open(DRV,"<$fname") or die "Report this as a BUG: Cannot open $fname";
	while(<DRV>) {
                	/^\s*sub\s+_Parse\s*{\s*$/ .. /^\s*}\s*#\s*_Parse\s*$/
        	and     do {
                	s/^#DBG>//;
                	push(@drv,$_);
        	}
	}
	close(DRV);

	$drv[0]=~s/_P/_DBP/;
	eval join('',@drv);
}

#Note that for loading debugging version of the driver,
#this file will be parsed from 'sub _Parse' up to '}#_Parse' inclusive.
#So, DO NOT remove comment at end of sub !!!
sub _Parse {
    my($self)=shift;

	my($rules,$states,$lex,$error)
     = @$self{ 'RULES', 'STATES', 'LEX', 'ERROR' };
	my($errstatus,$nberror,$token,$value,$stack,$check,$dotpos)
     = @$self{ 'ERRST', 'NBERR', 'TOKEN', 'VALUE', 'STACK', 'CHECK', 'DOTPOS' };

#DBG>	my($debug)=$$self{DEBUG};
#DBG>	my($dbgerror)=0;

#DBG>	my($ShowCurToken) = sub {
#DBG>		my($tok)='>';
#DBG>		for (split('',$$token)) {
#DBG>			$tok.=		(ord($_) < 32 or ord($_) > 126)
#DBG>					?	sprintf('<%02X>',ord($_))
#DBG>					:	$_;
#DBG>		}
#DBG>		$tok.='<';
#DBG>	};

	$$errstatus=0;
	$$nberror=0;
	($$token,$$value)=(undef,undef);
	@$stack=( [ 0, undef ] );
	$$check='';

    while(1) {
        my($actions,$act,$stateno);

        $stateno=$$stack[-1][0];
        $actions=$$states[$stateno];

#DBG>	print STDERR ('-' x 40),"\n";
#DBG>		$debug & 0x2
#DBG>	and	print STDERR "In state $stateno:\n";
#DBG>		$debug & 0x08
#DBG>	and	print STDERR "Stack:[".
#DBG>					 join(',',map { $$_[0] } @$stack).
#DBG>					 "]\n";


        if  (exists($$actions{ACTIONS})) {

				defined($$token)
            or	do {
				($$token,$$value)=&$lex($self);
#DBG>				$debug & 0x01
#DBG>			and	print STDERR "Need token. Got ".&$ShowCurToken."\n";
			};

            $act=   exists($$actions{ACTIONS}{$$token})
                    ?   $$actions{ACTIONS}{$$token}
                    :   exists($$actions{DEFAULT})
                        ?   $$actions{DEFAULT}
                        :   undef;
        }
        else {
            $act=$$actions{DEFAULT};
#DBG>			$debug & 0x01
#DBG>		and	print STDERR "Don't need token.\n";
        }

            defined($act)
        and do {

                $act > 0
            and do {        #shift

#DBG>				$debug & 0x04
#DBG>			and	print STDERR "Shift and go to state $act.\n";

					$$errstatus
				and	do {
					--$$errstatus;

#DBG>					$debug & 0x10
#DBG>				and	$dbgerror
#DBG>				and	$$errstatus == 0
#DBG>				and	do {
#DBG>					print STDERR "**End of Error recovery.\n";
#DBG>					$dbgerror=0;
#DBG>				};
				};


                push(@$stack,[ $act, $$value ]);

					$$token ne ''	#Don't eat the eof
				and	$$token=$$value=undef;
                next;
            };

            #reduce
            my($lhs,$len,$code,@sempar,$semval);
            ($lhs,$len,$code)=@{$$rules[-$act]};

#DBG>			$debug & 0x04
#DBG>		and	$act
#DBG>		and	print STDERR "Reduce using rule ".-$act." ($lhs,$len): ";

                $act
            or  $self->YYAccept();

            $$dotpos=$len;

                unpack('A1',$lhs) eq '@'    #In line rule
            and do {
                    $lhs =~ /^\@[0-9]+\-([0-9]+)$/
                or  die "In line rule name '$lhs' ill formed: ".
                        "report it as a BUG.\n";
                $$dotpos = $1;
            };

            @sempar =       $$dotpos
                        ?   map { $$_[1] } @$stack[ -$$dotpos .. -1 ]
                        :   ();

            $semval = $code ? &$code( $self, @sempar )
                            : @sempar ? $sempar[0] : undef;

            splice(@$stack,-$len,$len);

                $$check eq 'ACCEPT'
            and do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Accept.\n";

				return($semval);
			};

                $$check eq 'ABORT'
            and	do {

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Abort.\n";

				return(undef);

			};

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Back to state $$stack[-1][0], then ";

                $$check eq 'ERROR'
            or  do {
#DBG>				$debug & 0x04
#DBG>			and	print STDERR 
#DBG>				    "go to state $$states[$$stack[-1][0]]{GOTOS}{$lhs}.\n";

#DBG>				$debug & 0x10
#DBG>			and	$dbgerror
#DBG>			and	$$errstatus == 0
#DBG>			and	do {
#DBG>				print STDERR "**End of Error recovery.\n";
#DBG>				$dbgerror=0;
#DBG>			};

			    push(@$stack,
                     [ $$states[$$stack[-1][0]]{GOTOS}{$lhs}, $semval ]);
                $$check='';
                next;
            };

#DBG>			$debug & 0x04
#DBG>		and	print STDERR "Forced Error recovery.\n";

            $$check='';

        };

        #Error
            $$errstatus
        or   do {

            $$errstatus = 1;
            &$error($self);
                $$errstatus # if 0, then YYErrok has been called
            or  next;       # so continue parsing

#DBG>			$debug & 0x10
#DBG>		and	do {
#DBG>			print STDERR "**Entering Error recovery.\n";
#DBG>			++$dbgerror;
#DBG>		};

            ++$$nberror;

        };

			$$errstatus == 3	#The next token is not valid: discard it
		and	do {
				$$token eq ''	# End of input: no hope
			and	do {
#DBG>				$debug & 0x10
#DBG>			and	print STDERR "**At eof: aborting.\n";
				return(undef);
			};

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Dicard invalid token ".&$ShowCurToken.".\n";

			$$token=$$value=undef;
		};

        $$errstatus=3;

		while(	  @$stack
			  and (		not exists($$states[$$stack[-1][0]]{ACTIONS})
			        or  not exists($$states[$$stack[-1][0]]{ACTIONS}{error})
					or	$$states[$$stack[-1][0]]{ACTIONS}{error} <= 0)) {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Pop state $$stack[-1][0].\n";

			pop(@$stack);
		}

			@$stack
		or	do {

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**No state left on stack: aborting.\n";

			return(undef);
		};

		#shift the error token

#DBG>			$debug & 0x10
#DBG>		and	print STDERR "**Shift \$error token and go to state ".
#DBG>						 $$states[$$stack[-1][0]]{ACTIONS}{error}.
#DBG>						 ".\n";

		push(@$stack, [ $$states[$$stack[-1][0]]{ACTIONS}{error}, undef ]);

    }

    #never reached
	croak("Error in driver logic. Please, report it as a BUG");

}#_Parse
#DO NOT remove comment

1;

}
#End of include--------------------------------------------------

our @ISA = qw(Parse::Yapp::Driver VMXTemplate::Compiler);


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
			'error' => 7,
			"{{" => 4,
			'' => -1,
			'literal' => 6,
			"<!--" => 5
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 3
		DEFAULT => 0
	},
	{#State 4
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"{" => 12,
			"!" => 11,
			'name' => 19,
			"NOT" => 18
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'exp' => 20,
			'p11' => 13,
			'nonbrace' => 9
		}
	},
	{#State 5
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			"BLOCK" => 25,
			'literal' => 10,
			"FUNCTION" => 21,
			"{" => 12,
			"!" => 11,
			"FOR" => 22,
			"IF" => 35,
			"MACRO" => 23,
			"FOREACH" => 31,
			"SET" => 29,
			'name' => 19,
			"NOT" => 18
		},
		GOTOS => {
			'code_chunk' => 34,
			'for' => 33,
			'exp' => 24,
			'c_if' => 36,
			'c_for' => 28,
			'fn' => 30,
			'fn_def' => 32,
			'c_set' => 26,
			'c_fn' => 27,
			'varref' => 16,
			'p10' => 15,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 6
		DEFAULT => -5
	},
	{#State 7
		DEFAULT => -3
	},
	{#State 8
		DEFAULT => -4
	},
	{#State 9
		DEFAULT => -54
	},
	{#State 10
		DEFAULT => -59
	},
	{#State 11
		ACTIONS => {
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10,
			"(" => 17
		},
		GOTOS => {
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 37
		}
	},
	{#State 12
		ACTIONS => {
			"NOT" => 18,
			'name' => 19,
			"(" => 17,
			"-" => 14,
			"!" => 11,
			"{" => 12,
			'literal' => 10
		},
		DEFAULT => -72,
		GOTOS => {
			'varref' => 16,
			'pair' => 40,
			'p10' => 15,
			'gtpair' => 39,
			'nonbrace' => 9,
			'hash' => 41,
			'p11' => 13,
			'exp' => 38
		}
	},
	{#State 13
		DEFAULT => -52
	},
	{#State 14
		ACTIONS => {
			"(" => 17,
			'literal' => 10,
			"!" => 11,
			"{" => 12,
			'name' => 19,
			"NOT" => 18
		},
		GOTOS => {
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 42
		}
	},
	{#State 15
		DEFAULT => -51
	},
	{#State 16
		ACTIONS => {
			"[" => 44,
			"." => 45
		},
		DEFAULT => -60,
		GOTOS => {
			'varpart' => 43
		}
	},
	{#State 17
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12,
			'literal' => 10
		},
		GOTOS => {
			'p10' => 15,
			'exp' => 46,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 18
		ACTIONS => {
			"(" => 17,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12,
			'literal' => 10
		},
		GOTOS => {
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 47
		}
	},
	{#State 19
		ACTIONS => {
			'literal' => 10,
			'name' => 19,
			"{" => 12,
			"(" => 48
		},
		DEFAULT => -78,
		GOTOS => {
			'nonbrace' => 49,
			'varref' => 16
		}
	},
	{#State 20
		ACTIONS => {
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			">" => 55,
			"/" => 56,
			"+" => 57,
			"OR" => 58,
			"!=" => 50,
			"&" => 51,
			"&&" => 67,
			"==" => 66,
			"-" => 65,
			">=" => 68,
			".." => 59,
			"*" => 60,
			"}}" => 61,
			"||" => 63,
			"%" => 62,
			"AND" => 64
		}
	},
	{#State 21
		DEFAULT => -25
	},
	{#State 22
		DEFAULT => -28
	},
	{#State 23
		DEFAULT => -27
	},
	{#State 24
		ACTIONS => {
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			"/" => 56,
			">" => 55,
			"+" => 57,
			"OR" => 58,
			"!=" => 50,
			"&" => 51,
			"==" => 66,
			"&&" => 67,
			"-" => 65,
			">=" => 68,
			".." => 59,
			"*" => 60,
			"||" => 63,
			"%" => 62,
			"AND" => 64
		},
		DEFAULT => -12
	},
	{#State 25
		DEFAULT => -26
	},
	{#State 26
		DEFAULT => -9
	},
	{#State 27
		DEFAULT => -10
	},
	{#State 28
		DEFAULT => -11
	},
	{#State 29
		ACTIONS => {
			'name' => 70
		},
		GOTOS => {
			'varref' => 69
		}
	},
	{#State 30
		ACTIONS => {
			'name' => 71
		}
	},
	{#State 31
		DEFAULT => -29
	},
	{#State 32
		ACTIONS => {
			"=" => 73,
			"-->" => 72
		}
	},
	{#State 33
		ACTIONS => {
			'name' => 70
		},
		GOTOS => {
			'varref' => 74
		}
	},
	{#State 34
		ACTIONS => {
			"-->" => 75
		}
	},
	{#State 35
		ACTIONS => {
			"{" => 12,
			"!" => 11,
			'name' => 19,
			"NOT" => 18,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'p10' => 15,
			'exp' => 76,
			'varref' => 16
		}
	},
	{#State 36
		DEFAULT => -8
	},
	{#State 37
		DEFAULT => -56
	},
	{#State 38
		ACTIONS => {
			"||" => 63,
			"%" => 62,
			"AND" => 64,
			".." => 59,
			"*" => 60,
			">=" => 68,
			"-" => 65,
			"&&" => 67,
			"==" => 66,
			"," => 77,
			"!=" => 50,
			"&" => 51,
			">" => 55,
			"=>" => 78,
			"/" => 56,
			"+" => 57,
			"OR" => 58,
			"XOR" => 52,
			"<" => 53,
			"<=" => 54
		}
	},
	{#State 39
		DEFAULT => -76
	},
	{#State 40
		ACTIONS => {
			"," => 79
		},
		DEFAULT => -70
	},
	{#State 41
		ACTIONS => {
			"}" => 80
		}
	},
	{#State 42
		DEFAULT => -53
	},
	{#State 43
		DEFAULT => -79
	},
	{#State 44
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10
		},
		GOTOS => {
			'varref' => 16,
			'exp' => 81,
			'p10' => 15,
			'p11' => 13,
			'nonbrace' => 9
		}
	},
	{#State 45
		ACTIONS => {
			'name' => 82
		}
	},
	{#State 46
		ACTIONS => {
			"&" => 51,
			"!=" => 50,
			"<=" => 54,
			"<" => 53,
			"XOR" => 52,
			")" => 83,
			"OR" => 58,
			"+" => 57,
			"/" => 56,
			">" => 55,
			"*" => 60,
			".." => 59,
			"AND" => 64,
			"||" => 63,
			"%" => 62,
			"==" => 66,
			"-" => 65,
			"&&" => 67,
			">=" => 68
		}
	},
	{#State 47
		DEFAULT => -57
	},
	{#State 48
		ACTIONS => {
			"{" => 12,
			"!" => 11,
			'literal' => 10,
			")" => 87,
			"(" => 17,
			"-" => 14,
			"NOT" => 18,
			'name' => 19
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'gthash' => 88,
			'gtpair' => 86,
			'p11' => 13,
			'nonbrace' => 9,
			'list' => 85,
			'exp' => 84
		}
	},
	{#State 49
		DEFAULT => -64
	},
	{#State 50
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'exp' => 89,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 51
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12
		},
		GOTOS => {
			'p10' => 15,
			'exp' => 90,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 52
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19
		},
		GOTOS => {
			'exp' => 91,
			'p10' => 15,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 53
		ACTIONS => {
			"{" => 12,
			"!" => 11,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'exp' => 92,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 54
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12
		},
		GOTOS => {
			'nonbrace' => 9,
			'p11' => 13,
			'p10' => 15,
			'exp' => 93,
			'varref' => 16
		}
	},
	{#State 55
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"{" => 12,
			"!" => 11,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'varref' => 16,
			'exp' => 94,
			'p10' => 15
		}
	},
	{#State 56
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"{" => 12,
			"!" => 11,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'varref' => 16,
			'p10' => 15,
			'exp' => 95
		}
	},
	{#State 57
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10
		},
		GOTOS => {
			'varref' => 16,
			'exp' => 96,
			'p10' => 15,
			'p11' => 13,
			'nonbrace' => 9
		}
	},
	{#State 58
		ACTIONS => {
			"!" => 11,
			"{" => 12,
			'name' => 19,
			"NOT" => 18,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'p10' => 15,
			'exp' => 97,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 59
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12
		},
		GOTOS => {
			'varref' => 16,
			'exp' => 98,
			'p10' => 15,
			'p11' => 13,
			'nonbrace' => 9
		}
	},
	{#State 60
		ACTIONS => {
			'name' => 19,
			"NOT" => 18,
			"{" => 12,
			"!" => 11,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'nonbrace' => 9,
			'p11' => 13,
			'varref' => 16,
			'exp' => 99,
			'p10' => 15
		}
	},
	{#State 61
		DEFAULT => -7
	},
	{#State 62
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			'name' => 19,
			"NOT" => 18,
			"!" => 11,
			"{" => 12,
			'literal' => 10
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'exp' => 100,
			'p10' => 15,
			'varref' => 16
		}
	},
	{#State 63
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10
		},
		GOTOS => {
			'nonbrace' => 9,
			'p11' => 13,
			'varref' => 16,
			'p10' => 15,
			'exp' => 101
		}
	},
	{#State 64
		ACTIONS => {
			'name' => 19,
			"NOT" => 18,
			"!" => 11,
			"{" => 12,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'nonbrace' => 9,
			'p11' => 13,
			'varref' => 16,
			'exp' => 102,
			'p10' => 15
		}
	},
	{#State 65
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			'name' => 19,
			"NOT" => 18,
			"!" => 11,
			"{" => 12,
			'literal' => 10
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'p10' => 15,
			'exp' => 103,
			'varref' => 16
		}
	},
	{#State 66
		ACTIONS => {
			'literal' => 10,
			"!" => 11,
			"{" => 12,
			'name' => 19,
			"NOT" => 18,
			"-" => 14,
			"(" => 17
		},
		GOTOS => {
			'varref' => 16,
			'exp' => 104,
			'p10' => 15,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 67
		ACTIONS => {
			"!" => 11,
			"{" => 12,
			'name' => 19,
			"NOT" => 18,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'exp' => 105,
			'p10' => 15,
			'varref' => 16,
			'p11' => 13,
			'nonbrace' => 9
		}
	},
	{#State 68
		ACTIONS => {
			"NOT" => 18,
			'name' => 19,
			"{" => 12,
			"!" => 11,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'exp' => 106,
			'p10' => 15,
			'varref' => 16
		}
	},
	{#State 69
		ACTIONS => {
			"[" => 44,
			"-->" => 108,
			"=" => 107,
			"." => 45
		},
		GOTOS => {
			'varpart' => 43
		}
	},
	{#State 70
		DEFAULT => -78
	},
	{#State 71
		ACTIONS => {
			"(" => 109
		}
	},
	{#State 72
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 110
		}
	},
	{#State 73
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'varref' => 16,
			'p10' => 15,
			'exp' => 111
		}
	},
	{#State 74
		ACTIONS => {
			"[" => 44,
			"." => 45,
			"=" => 112
		},
		GOTOS => {
			'varpart' => 43
		}
	},
	{#State 75
		DEFAULT => -6
	},
	{#State 76
		ACTIONS => {
			"-->" => 113,
			"!=" => 50,
			"&" => 51,
			">" => 55,
			"/" => 56,
			"+" => 57,
			"OR" => 58,
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			".." => 59,
			"*" => 60,
			">=" => 68,
			"&&" => 67,
			"-" => 65,
			"==" => 66
		}
	},
	{#State 77
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12
		},
		GOTOS => {
			'nonbrace' => 9,
			'p11' => 13,
			'varref' => 16,
			'exp' => 114,
			'p10' => 15
		}
	},
	{#State 78
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"NOT" => 18,
			'name' => 19,
			"!" => 11,
			"{" => 12
		},
		GOTOS => {
			'p10' => 15,
			'exp' => 115,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 79
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"!" => 11,
			"{" => 12,
			"NOT" => 18,
			'name' => 19
		},
		DEFAULT => -72,
		GOTOS => {
			'varref' => 16,
			'pair' => 40,
			'gtpair' => 39,
			'p10' => 15,
			'p11' => 13,
			'nonbrace' => 9,
			'hash' => 116,
			'exp' => 38
		}
	},
	{#State 80
		DEFAULT => -58
	},
	{#State 81
		ACTIONS => {
			"&" => 51,
			"]" => 117,
			"!=" => 50,
			"<=" => 54,
			"<" => 53,
			"XOR" => 52,
			"OR" => 58,
			"+" => 57,
			"/" => 56,
			">" => 55,
			"*" => 60,
			".." => 59,
			"AND" => 64,
			"%" => 62,
			"||" => 63,
			"&&" => 67,
			"-" => 65,
			"==" => 66,
			">=" => 68
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
		ACTIONS => {
			"XOR" => 52,
			"<=" => 54,
			"<" => 53,
			"+" => 57,
			">" => 55,
			"/" => 56,
			"=>" => 78,
			"OR" => 58,
			"!=" => 50,
			"&" => 51,
			"," => 120,
			"==" => 66,
			"&&" => 67,
			"-" => 65,
			">=" => 68,
			"*" => 60,
			".." => 59,
			"AND" => 64,
			"%" => 62,
			"||" => 63
		},
		DEFAULT => -65
	},
	{#State 85
		ACTIONS => {
			")" => 121
		}
	},
	{#State 86
		ACTIONS => {
			"," => 122
		},
		DEFAULT => -73
	},
	{#State 87
		DEFAULT => -61
	},
	{#State 88
		ACTIONS => {
			")" => 123
		}
	},
	{#State 89
		ACTIONS => {
			"<=" => undef,
			"<" => undef,
			"+" => 57,
			">" => undef,
			"/" => 56,
			"!=" => undef,
			"&" => 51,
			"==" => undef,
			"-" => 65,
			">=" => undef,
			"*" => 60,
			"%" => 62
		},
		DEFAULT => -40
	},
	{#State 90
		ACTIONS => {
			"%" => 62,
			"*" => 60,
			"/" => 56
		},
		DEFAULT => -47
	},
	{#State 91
		ACTIONS => {
			"*" => 60,
			"AND" => 64,
			"%" => 62,
			"&&" => 67,
			"-" => 65,
			"==" => 66,
			">=" => 68,
			"&" => 51,
			"!=" => 50,
			"<=" => 54,
			"<" => 53,
			"+" => 57,
			"/" => 56,
			">" => 55
		},
		DEFAULT => -36
	},
	{#State 92
		ACTIONS => {
			">=" => undef,
			"==" => undef,
			"-" => 65,
			"%" => 62,
			"*" => 60,
			">" => undef,
			"/" => 56,
			"+" => 57,
			"<" => undef,
			"<=" => undef,
			"&" => 51,
			"!=" => undef
		},
		DEFAULT => -41
	},
	{#State 93
		ACTIONS => {
			"*" => 60,
			"%" => 62,
			"==" => undef,
			"-" => 65,
			">=" => undef,
			"!=" => undef,
			"&" => 51,
			"<=" => undef,
			"<" => undef,
			"+" => 57,
			">" => undef,
			"/" => 56
		},
		DEFAULT => -43
	},
	{#State 94
		ACTIONS => {
			"<=" => undef,
			"<" => undef,
			"+" => 57,
			"/" => 56,
			">" => undef,
			"&" => 51,
			"!=" => undef,
			"==" => undef,
			"-" => 65,
			">=" => undef,
			"*" => 60,
			"%" => 62
		},
		DEFAULT => -42
	},
	{#State 95
		DEFAULT => -49
	},
	{#State 96
		ACTIONS => {
			"/" => 56,
			"&" => 51,
			"*" => 60,
			"%" => 62
		},
		DEFAULT => -45
	},
	{#State 97
		ACTIONS => {
			"*" => 60,
			"%" => 62,
			"AND" => 64,
			"&&" => 67,
			"-" => 65,
			"==" => 66,
			">=" => 68,
			"&" => 51,
			"!=" => 50,
			"<" => 53,
			"<=" => 54,
			">" => 55,
			"/" => 56,
			"+" => 57
		},
		DEFAULT => -35
	},
	{#State 98
		ACTIONS => {
			"==" => 66,
			"&&" => 67,
			"-" => 65,
			">=" => 68,
			"*" => 60,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			">" => 55,
			"/" => 56,
			"+" => 57,
			"OR" => 58,
			"!=" => 50,
			"&" => 51
		},
		DEFAULT => -33
	},
	{#State 99
		DEFAULT => -48
	},
	{#State 100
		DEFAULT => -50
	},
	{#State 101
		ACTIONS => {
			"!=" => 50,
			"&" => 51,
			"+" => 57,
			">" => 55,
			"/" => 56,
			"<=" => 54,
			"<" => 53,
			"AND" => 64,
			"%" => 62,
			"*" => 60,
			">=" => 68,
			"==" => 66,
			"-" => 65,
			"&&" => 67
		},
		DEFAULT => -34
	},
	{#State 102
		ACTIONS => {
			"<" => 53,
			"<=" => 54,
			">" => 55,
			"/" => 56,
			"+" => 57,
			"&" => 51,
			"!=" => 50,
			"==" => 66,
			"-" => 65,
			">=" => 68,
			"*" => 60,
			"%" => 62
		},
		DEFAULT => -38
	},
	{#State 103
		ACTIONS => {
			"&" => 51,
			"/" => 56,
			"*" => 60,
			"%" => 62
		},
		DEFAULT => -46
	},
	{#State 104
		ACTIONS => {
			"!=" => undef,
			"&" => 51,
			"/" => 56,
			">" => undef,
			"+" => 57,
			"<" => undef,
			"<=" => undef,
			"%" => 62,
			"*" => 60,
			">=" => undef,
			"==" => undef,
			"-" => 65
		},
		DEFAULT => -39
	},
	{#State 105
		ACTIONS => {
			"*" => 60,
			"%" => 62,
			"-" => 65,
			"==" => 66,
			">=" => 68,
			"!=" => 50,
			"&" => 51,
			"<=" => 54,
			"<" => 53,
			"+" => 57,
			">" => 55,
			"/" => 56
		},
		DEFAULT => -37
	},
	{#State 106
		ACTIONS => {
			"+" => 57,
			"/" => 56,
			">" => undef,
			"<=" => undef,
			"<" => undef,
			"!=" => undef,
			"&" => 51,
			">=" => undef,
			"-" => 65,
			"==" => undef,
			"%" => 62,
			"*" => 60
		},
		DEFAULT => -44
	},
	{#State 107
		ACTIONS => {
			"{" => 12,
			"!" => 11,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'varref' => 16,
			'exp' => 124,
			'p10' => 15,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 108
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 125
		}
	},
	{#State 109
		ACTIONS => {
			'name' => 127
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 126
		}
	},
	{#State 110
		ACTIONS => {
			'error' => 7,
			'literal' => 6,
			"<!--" => 128,
			"{{" => 4
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 111
		ACTIONS => {
			".." => 59,
			"*" => 60,
			"||" => 63,
			"%" => 62,
			"AND" => 64,
			"-" => 65,
			"==" => 66,
			"&&" => 67,
			">=" => 68,
			"&" => 51,
			"!=" => 50,
			"<" => 53,
			"<=" => 54,
			"XOR" => 52,
			"OR" => 58,
			">" => 55,
			"/" => 56,
			"+" => 57
		},
		DEFAULT => -22
	},
	{#State 112
		ACTIONS => {
			'literal' => 10,
			"!" => 11,
			"{" => 12,
			'name' => 19,
			"NOT" => 18,
			"-" => 14,
			"(" => 17
		},
		GOTOS => {
			'p11' => 13,
			'nonbrace' => 9,
			'varref' => 16,
			'exp' => 129,
			'p10' => 15
		}
	},
	{#State 113
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 130
		}
	},
	{#State 114
		ACTIONS => {
			"&&" => 67,
			"-" => 65,
			"==" => 66,
			">=" => 68,
			".." => 59,
			"*" => 60,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			">" => 55,
			"/" => 56,
			"+" => 57,
			"OR" => 58,
			"!=" => 50,
			"&" => 51
		},
		DEFAULT => -75
	},
	{#State 115
		ACTIONS => {
			"!=" => 50,
			"&" => 51,
			"/" => 56,
			">" => 55,
			"+" => 57,
			"OR" => 58,
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			".." => 59,
			"*" => 60,
			">=" => 68,
			"==" => 66,
			"&&" => 67,
			"-" => 65
		},
		DEFAULT => -77
	},
	{#State 116
		DEFAULT => -71
	},
	{#State 117
		DEFAULT => -81
	},
	{#State 118
		ACTIONS => {
			"!" => 11,
			"{" => 12,
			'literal' => 10,
			"(" => 17,
			")" => 131,
			"-" => 14,
			"NOT" => 18,
			'name' => 19
		},
		GOTOS => {
			'varref' => 16,
			'exp' => 133,
			'p10' => 15,
			'p11' => 13,
			'nonbrace' => 9,
			'list' => 132
		}
	},
	{#State 119
		ACTIONS => {
			"." => 45,
			"[" => 44
		},
		DEFAULT => -55,
		GOTOS => {
			'varpart' => 134
		}
	},
	{#State 120
		ACTIONS => {
			"{" => 12,
			"!" => 11,
			'name' => 19,
			"NOT" => 18,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'p11' => 13,
			'list' => 135,
			'nonbrace' => 9,
			'exp' => 133,
			'p10' => 15,
			'varref' => 16
		}
	},
	{#State 121
		DEFAULT => -62
	},
	{#State 122
		ACTIONS => {
			"NOT" => 18,
			'name' => 19,
			"{" => 12,
			"!" => 11,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'varref' => 16,
			'gthash' => 137,
			'exp' => 136,
			'gtpair' => 86,
			'p10' => 15,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 123
		DEFAULT => -63
	},
	{#State 124
		ACTIONS => {
			"*" => 60,
			".." => 59,
			"AND" => 64,
			"%" => 62,
			"||" => 63,
			"&&" => 67,
			"-" => 65,
			"==" => 66,
			">=" => 68,
			"&" => 51,
			"!=" => 50,
			"<=" => 54,
			"<" => 53,
			"XOR" => 52,
			"OR" => 58,
			"+" => 57,
			">" => 55,
			"/" => 56
		},
		DEFAULT => -19
	},
	{#State 125
		ACTIONS => {
			'error' => 7,
			"{{" => 4,
			'literal' => 6,
			"<!--" => 138
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 126
		ACTIONS => {
			")" => 139
		}
	},
	{#State 127
		ACTIONS => {
			"," => 140
		},
		DEFAULT => -67
	},
	{#State 128
		ACTIONS => {
			"END" => 141,
			"SET" => 29,
			"FOREACH" => 31,
			"NOT" => 18,
			'name' => 19,
			"FOR" => 22,
			"MACRO" => 23,
			"IF" => 35,
			'literal' => 10,
			"BLOCK" => 25,
			"{" => 12,
			"!" => 11,
			"FUNCTION" => 21,
			"-" => 14,
			"(" => 17
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'c_set' => 26,
			'c_fn' => 27,
			'p11' => 13,
			'nonbrace' => 9,
			'for' => 33,
			'code_chunk' => 34,
			'c_if' => 36,
			'exp' => 24,
			'fn_def' => 32,
			'c_for' => 28,
			'fn' => 30
		}
	},
	{#State 129
		ACTIONS => {
			"&" => 51,
			"!=" => 50,
			"-->" => 142,
			"<" => 53,
			"<=" => 54,
			"XOR" => 52,
			"OR" => 58,
			">" => 55,
			"/" => 56,
			"+" => 57,
			".." => 59,
			"*" => 60,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			"==" => 66,
			"&&" => 67,
			"-" => 65,
			">=" => 68
		}
	},
	{#State 130
		ACTIONS => {
			"{{" => 4,
			'literal' => 6,
			"<!--" => 144,
			'error' => 7
		},
		GOTOS => {
			'chunk' => 8,
			'c_elseifs' => 143
		}
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
			".." => 59,
			"*" => 60,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			"-" => 65,
			"==" => 66,
			"&&" => 67,
			">=" => 68,
			"&" => 51,
			"!=" => 50,
			"," => 120,
			"<" => 53,
			"<=" => 54,
			"XOR" => 52,
			"OR" => 58,
			"/" => 56,
			">" => 55,
			"+" => 57
		},
		DEFAULT => -65
	},
	{#State 134
		DEFAULT => -85
	},
	{#State 135
		DEFAULT => -66
	},
	{#State 136
		ACTIONS => {
			"==" => 66,
			"&&" => 67,
			"-" => 65,
			">=" => 68,
			".." => 59,
			"*" => 60,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			"XOR" => 52,
			"<" => 53,
			"<=" => 54,
			">" => 55,
			"=>" => 78,
			"/" => 56,
			"+" => 57,
			"OR" => 58,
			"!=" => 50,
			"&" => 51
		}
	},
	{#State 137
		DEFAULT => -74
	},
	{#State 138
		ACTIONS => {
			'name' => 19,
			"NOT" => 18,
			"END" => 146,
			"SET" => 29,
			"FOREACH" => 31,
			"IF" => 35,
			"MACRO" => 23,
			"FOR" => 22,
			"{" => 12,
			"!" => 11,
			"FUNCTION" => 21,
			'literal' => 10,
			"BLOCK" => 25,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'c_set' => 26,
			'c_fn' => 27,
			'p11' => 13,
			'nonbrace' => 9,
			'for' => 33,
			'code_chunk' => 34,
			'c_if' => 36,
			'exp' => 24,
			'fn_def' => 32,
			'c_for' => 28,
			'fn' => 30
		}
	},
	{#State 139
		DEFAULT => -21
	},
	{#State 140
		ACTIONS => {
			'name' => 127
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 147
		}
	},
	{#State 141
		DEFAULT => -23
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
			"-" => 14,
			"FUNCTION" => 21,
			'literal' => 10,
			"MACRO" => 23,
			"FOR" => 22,
			"ELSIF" => 151,
			'name' => 19,
			"NOT" => 18,
			"(" => 17,
			"!" => 11,
			"{" => 12,
			"ELSEIF" => 150,
			"BLOCK" => 25,
			"IF" => 35,
			"ELSE" => 154,
			"END" => 153,
			"SET" => 29,
			"FOREACH" => 31
		},
		GOTOS => {
			'nonbrace' => 9,
			'elseif' => 152,
			'p11' => 13,
			'c_set' => 26,
			'c_fn' => 27,
			'varref' => 16,
			'p10' => 15,
			'c_for' => 28,
			'fn' => 30,
			'fn_def' => 32,
			'code_chunk' => 34,
			'for' => 33,
			'exp' => 24,
			'c_if' => 36
		}
	},
	{#State 145
		DEFAULT => -83
	},
	{#State 146
		DEFAULT => -20
	},
	{#State 147
		DEFAULT => -68
	},
	{#State 148
		ACTIONS => {
			'literal' => 6,
			"<!--" => 155,
			"{{" => 4,
			'error' => 7
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 149
		ACTIONS => {
			'literal' => 6,
			"<!--" => 156,
			"{{" => 4,
			'error' => 7
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 150
		DEFAULT => -32
	},
	{#State 151
		DEFAULT => -31
	},
	{#State 152
		ACTIONS => {
			"(" => 17,
			"-" => 14,
			"{" => 12,
			"!" => 11,
			"NOT" => 18,
			'name' => 19,
			'literal' => 10
		},
		GOTOS => {
			'varref' => 16,
			'p10' => 15,
			'exp' => 157,
			'nonbrace' => 9,
			'p11' => 13
		}
	},
	{#State 153
		DEFAULT => -13
	},
	{#State 154
		ACTIONS => {
			"-->" => 158,
			"IF" => 159
		}
	},
	{#State 155
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			'literal' => 10,
			"BLOCK" => 25,
			"{" => 12,
			"!" => 11,
			"FUNCTION" => 21,
			"FOR" => 22,
			"IF" => 35,
			"MACRO" => 23,
			"END" => 160,
			"SET" => 29,
			"FOREACH" => 31,
			'name' => 19,
			"NOT" => 18
		},
		GOTOS => {
			'c_set' => 26,
			'c_fn' => 27,
			'varref' => 16,
			'p10' => 15,
			'nonbrace' => 9,
			'p11' => 13,
			'code_chunk' => 34,
			'for' => 33,
			'c_if' => 36,
			'exp' => 24,
			'c_for' => 28,
			'fn' => 30,
			'fn_def' => 32
		}
	},
	{#State 156
		ACTIONS => {
			"MACRO" => 23,
			"FOR" => 22,
			"NOT" => 18,
			'name' => 19,
			"ELSIF" => 151,
			"-" => 14,
			"FUNCTION" => 21,
			'literal' => 10,
			"IF" => 35,
			"ELSE" => 162,
			"FOREACH" => 31,
			"END" => 163,
			"SET" => 29,
			"(" => 17,
			"ELSEIF" => 150,
			"{" => 12,
			"!" => 11,
			"BLOCK" => 25
		},
		GOTOS => {
			'exp' => 24,
			'c_if' => 36,
			'for' => 33,
			'code_chunk' => 34,
			'fn_def' => 32,
			'fn' => 30,
			'c_for' => 28,
			'p10' => 15,
			'varref' => 16,
			'c_fn' => 27,
			'c_set' => 26,
			'p11' => 13,
			'elseif' => 161,
			'nonbrace' => 9
		}
	},
	{#State 157
		ACTIONS => {
			"OR" => 58,
			">" => 55,
			"/" => 56,
			"+" => 57,
			"<" => 53,
			"<=" => 54,
			"XOR" => 52,
			"-->" => 164,
			"&" => 51,
			"!=" => 50,
			">=" => 68,
			"-" => 65,
			"&&" => 67,
			"==" => 66,
			"%" => 62,
			"||" => 63,
			"AND" => 64,
			".." => 59,
			"*" => 60
		}
	},
	{#State 158
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 165
		}
	},
	{#State 159
		DEFAULT => -30
	},
	{#State 160
		DEFAULT => -24
	},
	{#State 161
		ACTIONS => {
			'name' => 19,
			"NOT" => 18,
			"{" => 12,
			"!" => 11,
			'literal' => 10,
			"(" => 17,
			"-" => 14
		},
		GOTOS => {
			'nonbrace' => 9,
			'p11' => 13,
			'exp' => 166,
			'p10' => 15,
			'varref' => 16
		}
	},
	{#State 162
		ACTIONS => {
			"-->" => 167,
			"IF" => 159
		}
	},
	{#State 163
		DEFAULT => -15
	},
	{#State 164
		DEFAULT => -17
	},
	{#State 165
		ACTIONS => {
			'error' => 7,
			'literal' => 6,
			"<!--" => 168,
			"{{" => 4
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 166
		ACTIONS => {
			"!=" => 50,
			"&" => 51,
			"-->" => 169,
			"XOR" => 52,
			"<=" => 54,
			"<" => 53,
			"+" => 57,
			">" => 55,
			"/" => 56,
			"OR" => 58,
			"*" => 60,
			".." => 59,
			"AND" => 64,
			"||" => 63,
			"%" => 62,
			"==" => 66,
			"&&" => 67,
			"-" => 65,
			">=" => 68
		}
	},
	{#State 167
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 170
		}
	},
	{#State 168
		ACTIONS => {
			"FUNCTION" => 21,
			"{" => 12,
			"!" => 11,
			"BLOCK" => 25,
			'literal' => 10,
			"(" => 17,
			"-" => 14,
			'name' => 19,
			"NOT" => 18,
			"FOREACH" => 31,
			"SET" => 29,
			"END" => 171,
			"IF" => 35,
			"MACRO" => 23,
			"FOR" => 22
		},
		GOTOS => {
			'c_fn' => 27,
			'c_set' => 26,
			'p10' => 15,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13,
			'c_if' => 36,
			'exp' => 24,
			'for' => 33,
			'code_chunk' => 34,
			'fn' => 30,
			'c_for' => 28,
			'fn_def' => 32
		}
	},
	{#State 169
		DEFAULT => -18
	},
	{#State 170
		ACTIONS => {
			'error' => 7,
			"<!--" => 172,
			'literal' => 6,
			"{{" => 4
		},
		GOTOS => {
			'chunk' => 8
		}
	},
	{#State 171
		DEFAULT => -14
	},
	{#State 172
		ACTIONS => {
			"-" => 14,
			"(" => 17,
			"BLOCK" => 25,
			'literal' => 10,
			"FUNCTION" => 21,
			"!" => 11,
			"{" => 12,
			"FOR" => 22,
			"MACRO" => 23,
			"IF" => 35,
			"FOREACH" => 31,
			"SET" => 29,
			"END" => 173,
			'name' => 19,
			"NOT" => 18
		},
		GOTOS => {
			'exp' => 24,
			'c_if' => 36,
			'code_chunk' => 34,
			'for' => 33,
			'fn' => 30,
			'c_for' => 28,
			'fn_def' => 32,
			'c_fn' => 27,
			'c_set' => 26,
			'p10' => 15,
			'varref' => 16,
			'nonbrace' => 9,
			'p11' => 13
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
#line 30 "template.skel.pm"
    ), $class;
    $self->{options} = $options;
    return $self;
}

1;
