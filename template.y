// Контекстно-свободная грамматика шаблонизатора

// Подразумевается, что лексический анализатор зависим от работы синтаксического,
// знает о его состоянии и соответственно выдаёт либо лексемы "внутри" блоков кода,
// либо литералы "вне" оных

// Олдстайл BEGIN .. END ликвидирован

// TODO foreach ... as key => value

%token literal
%token name

%left ".."
%left "||" "OR" "XOR"
%left "&&" "AND"
%left "&"
%nonassoc "==" "!=" "<" ">" "<=" ">="
%left "+" "-"
%left "*" "/" "%"

%%
chunks: | chunks chunk
chunk: error | literal | "<!--" code_chunk "-->" | "{" exp "}"
code_chunk: c_if | c_set | c_fn | c_for | exp
c_if: "IF" exp "-->" chunks "<!--" "END" |
    "IF" exp "-->" chunks "<!--" "ELSE" "-->" chunks "<!--" "END" |
    "IF" exp "-->" chunks c_elseifs chunks "<!--" "END" |
    "IF" exp "-->" chunks c_elseifs chunks "<!--" "ELSE" "-->" chunks "<!--" "END"
c_elseifs: "<!--" elseif exp "-->" | c_elseifs chunks "<!--" elseif exp "-->"
c_set: "SET" varref "=" exp | "SET" varref "-->" chunks "<!--" "END"
c_fn: fn name "(" arglist ")" "=" exp | fn name "(" arglist ")" "-->" chunks "<!--" "END"
c_for: for varref "=" exp "-->" chunks "<!--" "END"
fn: "FUNCTION" | "BLOCK" | "MACRO"
for: "FOR" | "FOREACH"
elseif: "ELSE" "IF" | "ELSIF" | "ELSEIF"

exp: exp ".." exp |
    exp "||" exp | exp "OR" exp | exp "XOR" exp |
    exp "&&" exp | exp "AND" exp |
    exp "&" exp |
    exp "==" exp | exp "!=" exp |
    exp "<" exp | exp ">" exp | exp "<=" exp | exp ">=" exp |
    exp "+" exp | exp "-" exp |
    exp "*" exp | exp "/" exp | exp "%" exp |
    p10
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
