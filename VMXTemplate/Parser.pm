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
			"OR" => 105,
			"MACRO" => 106,
			"BLOCK" => 107,
			"ELSIF" => 108,
			"FOREACH" => 109,
			"ELSE" => 110,
			"SET" => 112,
			"END" => 113,
			"AND" => 114,
			'name' => 115,
			"XOR" => 116,
			"ELSEIF" => 117,
			"IF" => 118,
			"FOR" => 119,
			"NOT" => 120,
			"FUNCTION" => 121
		},
		GOTOS => {
			'namekw' => 111
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
			")" => 122,
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
			'chunks' => 123
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
			'exp' => 124,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 72
		ACTIONS => {
			"(" => 125
		}
	},
	{#State 73
		ACTIONS => {
			"-->" => 126,
			"[" => 63,
			"." => 64,
			"=" => 127
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
			"=" => 128
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
			"-->" => 129,
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
			")" => 130
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
			"," => 131,
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
			"," => 132
		},
		DEFAULT => -73
	},
	{#State 99
		ACTIONS => {
			")" => 133
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
			'hash' => 134,
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
			'exp' => 135,
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
			'exp' => 136,
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
			"]" => 137,
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
		DEFAULT => -93
	},
	{#State 106
		DEFAULT => -99
	},
	{#State 107
		DEFAULT => -98
	},
	{#State 108
		DEFAULT => -90
	},
	{#State 109
		DEFAULT => -101
	},
	{#State 110
		DEFAULT => -89
	},
	{#State 111
		ACTIONS => {
			"(" => 138
		},
		DEFAULT => -80
	},
	{#State 112
		DEFAULT => -92
	},
	{#State 113
		DEFAULT => -88
	},
	{#State 114
		DEFAULT => -95
	},
	{#State 115
		DEFAULT => -86
	},
	{#State 116
		DEFAULT => -94
	},
	{#State 117
		DEFAULT => -91
	},
	{#State 118
		DEFAULT => -87
	},
	{#State 119
		DEFAULT => -100
	},
	{#State 120
		DEFAULT => -96
	},
	{#State 121
		DEFAULT => -97
	},
	{#State 122
		DEFAULT => -84,
		GOTOS => {
			'varpath' => 139
		}
	},
	{#State 123
		ACTIONS => {
			'literal' => 3,
			"{{" => 4,
			'error' => 5,
			"<!--" => 140
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 124
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
	{#State 125
		ACTIONS => {
			'name' => 141
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 142
		}
	},
	{#State 126
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 143
		}
	},
	{#State 127
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
			'exp' => 144,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 128
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
			'exp' => 145,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 129
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 146
		}
	},
	{#State 130
		DEFAULT => -62
	},
	{#State 131
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
			'exp' => 148,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19,
			'list' => 147
		}
	},
	{#State 132
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
			'exp' => 149,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'gtpair' => 98,
			'p10' => 19,
			'gthash' => 150
		}
	},
	{#State 133
		DEFAULT => -63
	},
	{#State 134
		DEFAULT => -71
	},
	{#State 135
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
	{#State 136
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
	{#State 137
		DEFAULT => -81
	},
	{#State 138
		ACTIONS => {
			"-" => 9,
			"{" => 13,
			'name' => 12,
			'literal' => 15,
			"!" => 18,
			"(" => 17,
			"NOT" => 20,
			")" => 151
		},
		GOTOS => {
			'exp' => 148,
			'varref' => 14,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19,
			'list' => 152
		}
	},
	{#State 139
		ACTIONS => {
			"[" => 63,
			"." => 64
		},
		DEFAULT => -55,
		GOTOS => {
			'varpart' => 153
		}
	},
	{#State 140
		ACTIONS => {
			"END" => 154,
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
	{#State 141
		ACTIONS => {
			"," => 155
		},
		DEFAULT => -67
	},
	{#State 142
		ACTIONS => {
			")" => 156
		}
	},
	{#State 143
		ACTIONS => {
			'literal' => 3,
			"{{" => 4,
			'error' => 5,
			"<!--" => 157
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 144
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
	{#State 145
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
			"-->" => 158,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 146
		ACTIONS => {
			'literal' => 3,
			"{{" => 4,
			'error' => 5,
			"<!--" => 160
		},
		GOTOS => {
			'c_elseifs' => 159,
			'chunk' => 6
		}
	},
	{#State 147
		DEFAULT => -66
	},
	{#State 148
		ACTIONS => {
			".." => 39,
			"-" => 38,
			"OR" => 41,
			"<" => 40,
			"+" => 42,
			"%" => 43,
			"," => 131,
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
	{#State 149
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
	{#State 150
		DEFAULT => -74
	},
	{#State 151
		DEFAULT => -82
	},
	{#State 152
		ACTIONS => {
			")" => 161
		}
	},
	{#State 153
		DEFAULT => -85
	},
	{#State 154
		DEFAULT => -23
	},
	{#State 155
		ACTIONS => {
			'name' => 141
		},
		DEFAULT => -69,
		GOTOS => {
			'arglist' => 162
		}
	},
	{#State 156
		DEFAULT => -21
	},
	{#State 157
		ACTIONS => {
			"END" => 163,
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
	{#State 158
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 164
		}
	},
	{#State 159
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 165
		}
	},
	{#State 160
		ACTIONS => {
			"-" => 9,
			"MACRO" => 21,
			"BLOCK" => 22,
			"ELSIF" => 166,
			'literal' => 15,
			"!" => 18,
			"FOREACH" => 27,
			"ELSE" => 169,
			"END" => 167,
			"SET" => 30,
			"{" => 13,
			'name' => 12,
			"ELSEIF" => 168,
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
			'elseif' => 170,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 161
		DEFAULT => -83
	},
	{#State 162
		DEFAULT => -68
	},
	{#State 163
		DEFAULT => -20
	},
	{#State 164
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 171
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 165
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
	{#State 166
		DEFAULT => -31
	},
	{#State 167
		DEFAULT => -13
	},
	{#State 168
		DEFAULT => -32
	},
	{#State 169
		ACTIONS => {
			"IF" => 173,
			"-->" => 174
		}
	},
	{#State 170
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
			'exp' => 175,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 171
		ACTIONS => {
			"SET" => 30,
			"END" => 176,
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
	{#State 172
		ACTIONS => {
			"-" => 9,
			"MACRO" => 21,
			"BLOCK" => 22,
			"ELSIF" => 166,
			'literal' => 15,
			"!" => 18,
			"ELSE" => 178,
			"FOREACH" => 27,
			"END" => 177,
			"SET" => 30,
			"{" => 13,
			'name' => 12,
			"ELSEIF" => 168,
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
			'elseif' => 179,
			'c_fn' => 35,
			'fn' => 28
		}
	},
	{#State 173
		DEFAULT => -30
	},
	{#State 174
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 180
		}
	},
	{#State 175
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
			"-->" => 181,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 176
		DEFAULT => -24
	},
	{#State 177
		DEFAULT => -15
	},
	{#State 178
		ACTIONS => {
			"IF" => 173,
			"-->" => 182
		}
	},
	{#State 179
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
			'exp' => 183,
			'p11' => 16,
			'nonbrace' => 11,
			'p10' => 19
		}
	},
	{#State 180
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 184
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 181
		DEFAULT => -17
	},
	{#State 182
		DEFAULT => -2,
		GOTOS => {
			'chunks' => 185
		}
	},
	{#State 183
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
			"-->" => 186,
			"/" => 53,
			"XOR" => 54,
			"<=" => 55,
			">" => 56
		}
	},
	{#State 184
		ACTIONS => {
			"SET" => 30,
			"END" => 187,
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
	{#State 185
		ACTIONS => {
			'literal' => 3,
			'error' => 5,
			"{{" => 4,
			"<!--" => 188
		},
		GOTOS => {
			'chunk' => 6
		}
	},
	{#State 186
		DEFAULT => -18
	},
	{#State 187
		DEFAULT => -14
	},
	{#State 188
		ACTIONS => {
			"SET" => 30,
			"END" => 189,
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
	{#State 189
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
    ($_[1][0] ne "''" && $_[1][0] ne '""' ? '$t .= ' . $_[1][0] . ";\n" : '');
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
	],
	[#Rule 86
		 'namekw', 1, undef
	],
	[#Rule 87
		 'namekw', 1, undef
	],
	[#Rule 88
		 'namekw', 1, undef
	],
	[#Rule 89
		 'namekw', 1, undef
	],
	[#Rule 90
		 'namekw', 1, undef
	],
	[#Rule 91
		 'namekw', 1, undef
	],
	[#Rule 92
		 'namekw', 1, undef
	],
	[#Rule 93
		 'namekw', 1, undef
	],
	[#Rule 94
		 'namekw', 1, undef
	],
	[#Rule 95
		 'namekw', 1, undef
	],
	[#Rule 96
		 'namekw', 1, undef
	],
	[#Rule 97
		 'namekw', 1, undef
	],
	[#Rule 98
		 'namekw', 1, undef
	],
	[#Rule 99
		 'namekw', 1, undef
	],
	[#Rule 100
		 'namekw', 1, undef
	],
	[#Rule 101
		 'namekw', 1, undef
	]
],
#line 30 "template.skel.pm"
    ), $class;
    $self->{options} = $options;
    return $self;
}

1;
