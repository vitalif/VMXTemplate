// Контекстно-свободная грамматика шаблонизатора

// Подразумевается, что лексический анализатор зависим от работы синтаксического,
// знает о его состоянии и соответственно выдаёт либо лексемы "внутри" блоков кода,
// либо литералы "вне" оных

// Олдстайл BEGIN .. END ликвидирован
// Возможно, нужно сделать foreach ... as key => value

%token literal
%token name

%left ".."
%left "||" "or" "xor"
%left "&&" "and"
%nonassoc "==" "!=" "<" ">" "<=" ">="
%left "+" "-"
%left "&"
%left "*" "/" "%"

%%
chunks: | chunks chunk
chunk: literal | "<!--" code_chunk "-->" | "{" exp "}" | error
code_chunk: c_if | c_set | c_fn | c_for | exp
c_if: "if" exp "-->" chunks "<!--" "end" |
    "if" exp "-->" chunks "<!--" "else" "-->" chunks "<!--" "end" |
    "if" exp "-->" chunks c_elseifs chunks "<!--" "end" |
    "if" exp "-->" chunks c_elseifs chunks "<!--" "else" "-->" chunks "<!--" "end"
c_elseifs: "<!--" elseif exp "-->" | c_elseifs chunks "<!--" elseif exp "-->"
c_set: "set" varref "=" exp | "set" varref "-->" chunks "<!--" "end"
c_fn: fn name "(" arglist ")" "=" exp | fn name "(" arglist ")" "-->" chunks "<!--" "end"
c_for: for varref "=" exp "-->" chunks "<!--" "end"
fn: "function" | "block" | "macro"
for: "for" | "foreach"
elseif: "else" "if" | "elsif" | "elseif"

exp: exp ".." exp |
    exp "||" exp | exp "or" exp | exp "xor" exp |
    exp "&&" exp | exp "and" exp |
    exp "==" exp | exp "!=" exp |
    exp "<" exp | exp ">" exp | exp "<=" exp | exp ">=" exp |
    exp "+" exp | exp "-" exp |
    exp "&" exp |
    exp "*" exp | exp "/" exp | exp "%" exp |
    p10
p10: p11 | '-' p11
p11: nonbrace | '(' exp ')' varpath | '!' p11 | "not" p11
nonbrace: '{' hash '}' | literal | varref | name '(' ')' | name '(' list ')' | name '(' gthash ')' | name nonbrace | method '(' ')' | method '(' list ')'
method: varref '.' name
list: exp | exp ',' list
arglist: name | name ',' arglist |
hash: pair | pair ',' hash |
gthash: gtpair | gtpair ',' gthash
pair: exp ',' exp | gtpair
gtpair: exp "=>" exp
varref: name | varref varpart
varpart: '.' name | '[' exp ']'
varpath: | varpath varpart
%%
