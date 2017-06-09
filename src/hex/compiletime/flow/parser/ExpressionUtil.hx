package hex.compiletime.flow.parser;

#if macro
import haxe.macro.Expr;
import haxe.macro.ExprTools;

/**
 * ...
 * @author Francis Bourre
 */
@:final
class ExpressionUtil 
{
	/** @private */ function new() throw new hex.error.PrivateConstructorException();

	static public function compressField( e : Expr, ?previousValue : String = "" ) : String
	{
		return switch( e.expr )
		{
			case EField( ee, field ):
				previousValue = previousValue == "" ? field : field + "." + previousValue;
				return compressField( ee, previousValue );
				
			case EConst(CIdent(id)):
				return previousValue == "" ? id : id + "." + previousValue;

			default:
				return previousValue;
		}
	}
	
	static public function getFullClassDeclaration( tp : TypePath ) : String
	{
		var className = ExprTools.toString( macro new $tp() );
		return className.split( "new " ).join( '' ).split( '()' ).join( '' );
	}
}
#end