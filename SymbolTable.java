import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.LinkedList;

class SymbolTable implements Scope
{
    private Map<String,SymEntry> symbols;
    private List<Scope> children;
    Scope parentScope;
    String name;

    public SymbolTable( Scope parent, String name )
    {
    	parentScope = parent;
        if ( parent != null ) {
	    parent.addChild( this );
        }
    	this.name = name;
        symbols = new HashMap<String,SymEntry>();
        children = new LinkedList<Scope>();
        System.out.println( "Created SymbolTable " + name + (parent == null ? "" : " inside parent " + parent.getScopeName()) );
    }

    public void addChild( Scope child )
    {
        children.add( child );
    }

	/*
	public void add( String name, SymEntry theType, boolean declare )
	{
	    String key = name.toUpperCase();
        if ( symbols.containsKey(key) ) {
			SymEntry e = symbols.get(key);
            if ( e.varType == VarType.UNKNOWN ) {
				e.varType = theType;
                symbols.put( key, e );
            } else if ( e.varType != theType ) {
				// FIXME: mismatched types
			}
        } else {
			SymEntry e = new SymEntry();
			e.varType = theType;
			e.needsDeclaration = declare;
			symbols.put( key, e );
		}
	}*/

	public String toStringNested( int indent )
	{
            String spaces = "";
	    if ( indent > 0 ) {
                spaces = String.format( "%" + indent + "s", "" );
            }
	    StringBuilder sb = new StringBuilder( spaces + getScopeName() + ": " + this.toString() + "\n" );
            for ( Scope child : children ) {
                sb.append( child.toStringNested(indent+2) );
            }
            return sb.toString();
	}

	public String toString()
	{
		return symbols.toString();
	}

	public List<String> getSt()
	{
		List<String> retVal = new ArrayList<String>();
		for ( Map.Entry<String, SymEntry> v : symbols.entrySet()) {
			//if ( v.getValue().needsDeclaration ) {
				retVal.add( v.getValue().varType + " " + v.getKey() );
			//}
		}
		return retVal;
	}

	@Override
	public String getScopeName() {
		if ( getParentScope() == null ) {
			return name;
		} else {
			return getParentScope().getScopeName() + "::" + name;
		}
	}

	@Override
	public Scope getParentScope() {
		return parentScope;
	}

	@Override
	public void define(SymEntry sym) {
		String name = sym.name.toUpperCase();
		symbols.put( name, sym );
		sym.scope = this;
	}

	@Override
	public SymEntry resolve(String name, boolean localOnly ) {
		String key = name.toUpperCase();
		SymEntry s = symbols.get( key );
		if ( !localOnly && s == null && getParentScope() != null ) {
			s = getParentScope().resolve( name, false );
		}
		return s;
	}
}
