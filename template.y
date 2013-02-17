// Грамматика Новой-Новой Версии шаблонизатора.
// Конфликтов нет.
// BEGIN, возможно, ещё будет ликвидирован.
// FIXME не хватает foreach($a as $k => $v)

%token literal
%token name

%%
inst: "<!--" code "-->" | "{" exp "}"
code: "IF" exp | "ELSE" | elseif exp | "END" | "END" varref |
    "SET" varref | "SET" varref '=' exp |
    fn name '(' arglist ')' | fn name '(' arglist ')' '=' exp |
    for varref '=' exp | for varref |
    "BEGIN" name bparam | exp
bparam: |
    bp1 | bp2 | bp3 |
    bp1 bp2 | bp2 bp1 | bp1 bp3 | bp3 bp1 | bp2 bp3 | bp3 bp2 |
    bp1 bp2 bp3 | bp1 bp3 bp2 | bp2 bp1 bp3 | bp2 bp3 bp1 | bp3 bp1 bp2 | bp3 bp2 bp1
bp1: "AT" exp
bp2: "BY" exp
bp3: "TO" exp
fn: "FUNCTION" | "BLOCK" | "MACRO"
for: "FOR" | "FOREACH"
elseif: "ELSE" "IF" | "ELSIF" | "ELSEIF"

exp: p4 | p4 "|" exp
p4: p5 | p5 "||" p4 | p5 "OR" p4 | p5 "XOR" p4
p5: p6 | p6 "&&" p5 | p6 "AND" p5
p6: p7 | p7 "==" p7 | p7 "!=" p7
p7: p8 | p8 '<' p8 | p8 '>' p8 | p8 "<=" p8 | p8 ">=" p8
p8: p9 | p9 '+' p8 | p9 '-' p8
p9: p10 | p10 '*' p9 | p10 '/' p9 | p10 '%' p9
p10: p11 | '-' p11
p11: nonbrace | '(' exp ')' varpath | '!' p11 | "NOT" p11
nonbrace: '{' hash '}' | literal | varref | func '(' list_or_gthash ')' | func nonbrace
list_or_gthash: list | gthash
func: name | varref varpart
list: exp | exp ',' list
arglist: name | name ',' arglist |
hash: pair | pair ',' hash |
gthash: gtpair | gtpair ',' gthash |
pair: exp ',' exp | gtpair
gtpair: exp "=>" exp
varref: name | varref varpart
varpart: '.' name | '[' exp ']'
varpath: | varpath varpart
%%
