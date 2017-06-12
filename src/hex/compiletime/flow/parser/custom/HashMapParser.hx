package hex.compiletime.flow.parser.custom;

/**
 * ...
 * @author Francis Bourre
 */
#if macro
import haxe.macro.*;
import hex.compiletime.flow.parser.ExpressionParser;
import hex.core.ContextTypeList;
import hex.vo.ConstructorVO;

class HashMapParser 
{
	/** @private */ function new() throw new hex.error.PrivateConstructorException();
	
	public static function parse( parser : ExpressionParser, id : ID, params : Array<Expr>, expr : Expr ) : ConstructorVO
	{
		var constructorVO : ConstructorVO;
		
		if ( params.length > 0 )
		{
			switch( params[ 0 ].expr )
			{
				case EArrayDecl( values ):
					var args = values.map( function(e) return parser.parseMapArgument( parser, id, e ) );
					constructorVO = new ConstructorVO( id, ContextTypeList.HASHMAP, args );
					
				case wtf:
					trace( wtf );
					haxe.macro.Context.error( '', haxe.macro.Context.currentPos() );
			}
		}
		
		constructorVO.filePosition = expr.pos;
		return constructorVO;
	}
}
#end