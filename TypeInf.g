tree grammar TypeInf;
options {
  tokenVocab = SpokenLang;
  ASTLabelType = SLTreeNode;
  filter = true;
}

@header {
    import java.util.Set;
    import java.util.HashSet;
    import java.util.Iterator;
}

@members {
    public Scope currentScope;
	public Set<VarConstraint> constraints = new HashSet();
    public SLTreeNode currentFunction;

    VarType matchTypes( VarType knownType, VarType matchType, SLTreeNode node )
    {
        if ( knownType == VarType.UNKNOWN ) {
            // If the LHS is unknown then the type it should be
            // set to is the RHS
            return matchType;
        } else {
            // The LHS has a known type, so make sure they match
            if ( matchType != VarType.UNKNOWN && knownType != matchType ) {
                throw new CompileException( "Incompatible types " + knownType + " and " + matchType + " for " + node.getText() + " at line " + node.getLine() );
            } else {
                return knownType;
            }
        }
    }

    void constrainType( SLTreeNode node, VarType vType )
    {
        if ( node.symbol == null ) {
            throw new CompileException( "Unresolved variable " + node.getText() + " at line " + node.getLine() );
        } else if ( vType == VarType.UNKNOWN || vType == null ) {
            return;
        } else if ( node.symbol.varType == VarType.FUNCTION ) {
            // Setting the return type of a function.  Use the returnType instead of
            // varType
            FunctionSym f = (FunctionSym)node.symbol;
            VarType t = matchTypes( f.returnType, vType, node );
            if ( t != VarType.UNKNOWN ) {
                f.returnType = t;
				System.out.println( "Constraint: typeof(" + node.getText() + ") = " + vType );
                // FIXME: add constraint
            }
        } else {
            // Try to set the variable type
            SymEntry s = node.symbol;
            VarType t = matchTypes( s.varType, vType, node );
            if ( t != VarType.UNKNOWN ) {
                s.varType = t;
				System.out.println( "Constraint: typeof(" + node.getText() + ") = " + vType );
                // FIXME: add constraint
            }
        }
    }

    void constrainTypeList( List<SLTreeNode> nodes, VarType vType )
    {
        for ( SLTreeNode n: nodes ) {
            constrainType( n, vType );
        }
    }

    void addConstraintList( SymEntry lhs, List<SLTreeNode> rhs )
    {
        for ( SLTreeNode s: rhs ) {
            addConstraint( lhs, s.symbol );
        }
    }

    void addConstraint( SymEntry lhs, SymEntry rhs )
    {
        constraints.add( new VarConstraint(lhs,rhs) );
        System.out.println( "New constraints: " + constraints );
    }

    void processConstraints()
    {
        while ( constraints.size() > 0 ) {
            int s = constraints.size();
            Iterator i = constraints.iterator();
            while ( i.hasNext() ) {
                VarConstraint v = (VarConstraint)i.next();
                if ( unifyTypes( v.v1, v.v2 ) ) {
                    i.remove();
                }
            }
            if ( s == constraints.size() ) {
                // FIXME: Didn't eliminate any constraints.
                break;
            }
        }
    }

    boolean unifyTypes( SymEntry v1, SymEntry v2 )
    {
        VarType t1 = (v1.varType == VarType.FUNCTION) ? ((FunctionSym)v1).returnType : v1.varType;
        VarType t2 = (v2.varType == VarType.FUNCTION) ? ((FunctionSym)v2).returnType : v2.varType;

        if ( t1 == VarType.UNKNOWN ) {
            if ( t2 == VarType.UNKNOWN ) {
                return false;
            } else {
                if ( v1.varType == VarType.FUNCTION ) {
                    ((FunctionSym)v1).returnType = t2;
                } else {
                    v1.varType = t2;
                }
                return true;
            }
        } else {
            if ( t2 == VarType.UNKNOWN ) {
                if ( v2.varType == VarType.FUNCTION ) {
                    ((FunctionSym)v2).returnType = t1;
                } else {
                    v2.varType = t1;
                }
                return true;
            } else {
                if ( t1 != t2 ) {
                    throw new CompileException( "Types of " + v1 + " and " + v2 + " are not compatible." );
                }
            }
        }

        return false;
    }

    VarType getFuncType( SLTreeNode node )
    {
        // Make sure node represents a function and then
        // return its returnType.
        if ( node.symbol == null ) {
            // Try to resolve the function.  It would have been previously skipped
            // if it was a forward reference.
            SymEntry var = currentFunction.scope.resolve( node.getText(), false );
            if ( var == null ) {
                throw new CompileException( "Unresolved function " + node.getText() + " at line " + node.getLine() );
            } else {
                node.symbol = var;
            }
        }
        
        if ( node.symbol.varType == VarType.FUNCTION ) {
            return ((FunctionSym)node.symbol).returnType;
        } else {
            throw new CompileException( "Can't call non-function symbol " + node.getText() + " at line " + node.getLine() );
        }
    }
}

// Topdown and bottomup tell ANTLR which rules
// to process as it goes down and then up the tree.
/*topdown
    :   enterBlock
    |	enterFunction
    |	funcArgs
    |	assignment
    |	atom
    ;*/

topdown
    :   enterFunction
    ;

bottomup
    :   exprRoot
	|	assignment
    |   returnStmt
    |   callStmt
    |   exitFunction
    ;

assignment
	:	^(ASSIGN ID rhs=exprRoot) 
        {
            constrainType( $ID, $rhs.type );
            addConstraintList( $ID.symbol, $rhs.vars );
            if ( $ID.evalType != VarType.UNKNOWN ) {
                constrainTypeList( $rhs.vars, $ID.evalType );
            }
        }
	;

returnStmt
    :   ^(RETURN rhs=.) { constrainType( currentFunction, $rhs.evalType ); }
    ;

callStmt returns [VarType type]
    :   ^(CALL ID .*) { $type = $CALL.evalType = getFuncType($ID); }
    ;

exprRoot returns [VarType type, List<SLTreeNode> vars]
	:	^(EXPR expr) { $type = $EXPR.evalType = $expr.type; $vars = $expr.vars; }
	;

expr returns [VarType type, List<SLTreeNode> vars]
    @after { System.out.println( "typeof(" + $expr.text + ") = " + $type ); }
	: atom { $type = $atom.type; $vars = $atom.vars; }
    | callStmt { $type = $callStmt.type; $vars = new ArrayList(); /* FIXME: Track function symbol */ }
	;
 
enterFunction
    :   ^(FUNCTION ID .*)
        {
            currentFunction = $ID;
            if ( currentFunction.symbol == null ) {
                throw new CompileException( "Unresolved function " + $ID.text + " entered at line " + $ID.line );
            }
        }
    ;

exitFunction
    :   FUNCTION
        {
            // If the function's type is unknown, set it to void
            // FIXME: We probably can't set this to void in the general case
            if ( ((FunctionSym)currentFunction.symbol).returnType == VarType.UNKNOWN ) {
                constrainType( currentFunction, VarType.VOID );
            }

            processConstraints();
        }
    ;

// Set scope for atoms in expressions, but don't define them
atom returns [VarType type, List<SLTreeNode> vars]
    @init { $vars = new ArrayList(); }
    @after { System.out.println( "Vars in " + $start.toStringTree() + ": " + $vars ); }
	:	INT 	{ $type = VarType.INT; }
	|	FLOAT 	{ $type = VarType.FLOAT; }
	|	STRING 	{ $type = VarType.STRING; }
	|	ID		
		{ 
            System.out.println( "Found ID " + $ID.text );
			if ( $ID.symbol == null ) {
				SymEntry s = $ID.scope.resolve( $ID.text, false );
				$ID.symbol = s;
			}

			$type = $ID.symbol.varType; 
            $vars.add( $ID );
		}
	|	binaryOp
        {
            $type = $binaryOp.type;
            $vars = $binaryOp.vars;
        }
	;

binaryOp returns [VarType type, List<SLTreeNode> vars]
    @after { $start.evalType = $type; }
	: 	binop a=exprRoot b=exprRoot 
		{ 
			if ( $a.type != VarType.UNKNOWN ) {
				$type = $a.start.evalType;
                constrainTypeList( $b.vars, $type );
                if ( $b.start.symbol != null ) {
                    constrainType( $b.start, $a.start.evalType );
                }
		   	} else {
				$type = $b.start.evalType;
                constrainTypeList( $a.vars, $type );
                if ( $a.start.symbol != null ) {
                    constrainType( $a.start, $b.start.evalType );
                }
			}
            $vars = $a.vars;
            $vars.addAll( $b.vars );
		}
	;

binop : '+' | '-' | '*' | '/' ;
