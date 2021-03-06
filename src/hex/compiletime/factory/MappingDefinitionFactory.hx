package hex.compiletime.factory;

#if macro
import haxe.macro.Expr;
import hex.core.ContextTypeList;
import hex.vo.ConstructorVO;
using Lambda;

/**
 * ...
 * @author Francis Bourre
 */
class MappingDefinitionFactory
{
	/** @private */ function new() throw new hex.error.PrivateConstructorException();

	static public function build<T:hex.compiletime.basic.vo.FactoryVOTypeDef>( factoryVO : T ) : Expr
	{
		var constructorVO 		= factoryVO.constructorVO;
		var idVar 				= constructorVO.ID;

		var result = constructorVO.arguments.fold
		( 
			function ( arg, e ) return addProperty( factoryVO.contextFactory, arg, e ), 
				macro @:pos( constructorVO.filePosition ) 
					$v{{ fromType: "", toValue: null, toClass: null, withName: "", asSingleton: false, injectInto: false }} 
		);
		
		//Check type matching
		var coreFactory		= factoryVO.contextFactory.getCoreFactory();
		var typelocator		= factoryVO.contextFactory.getTypeLocator();
		var checker = new hex.compiletime.basic.MappingDependencyChecker( coreFactory, typelocator );
		checker._getMappingDefinition( result, constructorVO.filePosition );
		//
		
		var ct = macro :hex.di.mapping.MappingDefinition;
		return constructorVO.shouldAssign ?
			return macro var $idVar : $ct = $result:
			return macro $result;
	}
	
	static function setPropertyValue( p : hex.vo.PropertyVO, o : Dynamic ) : Dynamic
	{
		Reflect.setField( o, p.name, p.value );
		return o;
	}

	static public function addProperty( factory : hex.compiletime.basic.IContextFactory, property : hex.vo.PropertyVO, expr : Expr ) : Expr
	{
		var value 			: Dynamic 	= null;
		var id							= property.ownerID;
		var propertyName				= property.name;
		
		switch( expr.expr )
		{
			case EObjectDecl( fields ):
	
				fields.remove( fields.find( function(arg) return arg.field == propertyName ) );
				if ( property.method != null )
				{
					var constructorVO 			= new ConstructorVO( null, ContextTypeList.FUNCTION, [ property.method ], null, null, false, null, null, null );
					constructorVO.filePosition 	= property.filePosition;
					value 						= factory.buildVO( constructorVO );
					fields.push( { field: propertyName, expr: value } );

				} else if ( property.ref != null )
				{
					var constructorVO 			= new ConstructorVO( null, ContextTypeList.INSTANCE, null, null, null, false, property.ref, null, null );
					constructorVO.filePosition 	= property.filePosition;
					value 						= factory.buildVO( constructorVO );
					fields.push( { field: propertyName, expr: macro $p{ property.ref.split('.') } } );

				} else if ( property.staticRef != null )
				{
					var constructorVO 			= new ConstructorVO( null, ContextTypeList.STATIC_VARIABLE, null, null, null, false, null, null,  property.staticRef );
					constructorVO.filePosition 	= property.filePosition;
					value 						= factory.buildVO( constructorVO );
					fields.push( { field: propertyName, expr: value } );
					
				} else if ( property.valueToBuild != null )
				{
					property.valueToBuild.filePosition = property.filePosition;
					value 						= factory.buildVO( property.valueToBuild );
					fields.push( { field: propertyName, expr: value } );

				} else
				{
					var type 					= property.type != null ? property.type : ContextTypeList.STRING;
					var constructorVO 			= new ConstructorVO( property.ownerID, type, [ property.value ], null, null, false, null, null, null );
					constructorVO.filePosition 	= property.filePosition;
					value 						= factory.buildVO( constructorVO );
					fields.push( { field: propertyName, expr: value } );
				}
				
			case wtf:
				trace( wtf );
		}

		return expr;
	}
}
#end