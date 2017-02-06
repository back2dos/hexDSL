package hex.compiletime.factory;

#if macro
import haxe.macro.Expr;
import hex.error.PrivateConstructorException;
import hex.vo.ConstructorVO;
import hex.vo.FactoryVODef;

/**
 * ...
 * @author Francis Bourre
 */
class ArgumentFactory
{
	/** @private */
    function new()
    {
        throw new PrivateConstructorException( );
    }
	
	static public function build<T:FactoryVODef>( factoryVO : T ) : Array<Expr>
	{
		var result 			= [];
		var factory 		= factoryVO.contextFactory;
		var constructorVO 	= factoryVO.constructorVO;
		
		for ( arg in constructorVO.arguments )
			result.push( factory.buildVO( arg ) );

		return result;
	}
}
#end