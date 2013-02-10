tree grammar SLJavaEmitter;

options {
    tokenVocab=SpokenLang;
    ASTLabelType=SLTreeNode;
    output=template;
}

@header {
	package org.bxg.spokencompiler;
}

program [String name,Scope symbols]
	:	f+=function+ -> program(fList={$f},name={$name}) ;

function
	:	^(FUNCTION ID argList? functionBody)	-> function(name={$ID.text},type={((FunctionSym)$ID.symbol).returnType},params={$argList.st},body={$functionBody.st})
	//|	^(FUNCTION ID functionBody)		-> function(name={$ID.text},body={$functionBody.st})
	;

argList
	:	^(ARG_LIST formal+=formalArg+ ) -> arglist(args={$formal})
	;

formalArg
	:	ID	-> {$ID.symbol.isArray}? formal_arg_array(type={$ID.symbol.varType},name={$ID.text})
			-> formal_arg(type={$ID.symbol.varType},name={$ID.text})
	;

functionBody
        :       ^(BLOCK el+=stmt+) -> block(body={$el})
        ;

stmt    
	:   assignment -> {$assignment.st}
	|	printStmt -> {$printStmt.st}
	|	whileStmt -> {$whileStmt.st}
	|	callStmt -> {$callStmt.st}
	|	returnStmt -> {$returnStmt.st}
	|	emptyStmt -> {$emptyStmt.st}
	|	ifStmt -> {$ifStmt.st}
	|	readStmt -> {$readStmt.st}
	;

whileStmt
	:	^(WHILE boolExpr functionBody)
	->	while(guard={$boolExpr.st},body={$functionBody.st})
	;
	
printStmt
	:	^(PRINT expr) 		-> printOut(string={$expr.st})
	|	PRINTLN 			-> printOut(string={"\"\\n\""})
	;

readStmt
	:	^(READ ID)						-> {$ID.symbol != null && $ID.symbol.definition == $ID}? readNewVar(type={$ID.symbol.varType},name={$ID.text})
										-> readVar(name={$ID.text},type={$ID.symbol.varType}) 
	|	^(READ ^(ARRAYREF atom ID))		-> {$ID.symbol != null && $ID.symbol.definition == $ID}? readNewArray(type={$ID.symbol.varType},name={$ID.text},index={$atom.st})
										-> readArray(name={$ID.text},index={$atom.st},type={$ID.symbol.varType})
	;
	
callStmt
	:	^(CALL ID args+=expr*)
	->	funcStmt(func={$ID.text},args={$args})
	;

returnStmt
	:	^(RETURN expr)
	->	return(expr={$expr.st})
	;

ifStmt
	:	^(IF boolExpr t=functionBody f=functionBody)
	->	ifStmt(cond={$boolExpr.st},trueBlock={$t.st},falseBlock={$f.st})
	;

assignment
		:		^(ASSIGN ^(ARRAYREF atom ID) expr) 	-> {$ID.symbol != null && $ID.symbol.definition == $ID}? newArray(type={$ID.symbol.varType},name={$ID.text},index={$atom.st},value={$expr.st})
													-> arrayAssign(name={$ID.text},index={$atom.st},value={$expr.st})
        |       ^(ASSIGN ID expr) 	-> {$ID.symbol != null && $ID.symbol.definition == $ID}? assign(type={$ID.symbol.varType},name={$ID.text},value={$expr.st})
									-> assign(name={$ID.text},value={$expr.st})
        ;

emptyStmt
	:	NOTHING
	->	//{%{"/* nothing */"}}	
		emptyStmt(junk={""})
	;

boolExpr
	:	^(o=CMPOP e1=expr e2=expr)		-> 	{$o.text.equals("=")}? expr(e1={$e1.st},e2={$e2.st},op={"=="})
										->	expr(e1={$e1.st},e2={$e2.st},op={$o.text})
	;

expr
	:	^(EXPR '+' e=expr e2=expr) -> expr(e1={$e.st},e2={$e2.st},op={"+"})
	|	^(EXPR '-' e=expr e2=expr) -> expr(e1={$e.st},e2={$e2.st},op={"-"})
	|	^(EXPR '*' e=expr e2=expr) -> expr(e1={$e.st},e2={$e2.st},op={"*"})
	|	^(EXPR '/' e=expr e2=expr) -> expr(e1={$e.st},e2={$e2.st},op={"/"})
	|	^(EXPR atom) -> {$atom.st}
	|	^(EXPR arrayRef) -> {$arrayRef.st}
	|	^(EXPR callExpr) -> {$callExpr.st}
	;

callExpr
	:	^(CALL ID args+=expr*)
	->	funcCall(func={$ID.text},args={$args})
	;

arrayRef
	:	^(ARRAYREF atom ID) -> arrayRef(index={$atom.st},array={$ID.text})
	;

atom	:       INT		-> int_constant(val={$INT.text})
        |       FLOAT 		-> float_constant(val={$FLOAT.text})
        |       STRING		-> string_constant(text={$STRING.text})
        |       ID 		-> ident(name={$ID.text})
        ;
