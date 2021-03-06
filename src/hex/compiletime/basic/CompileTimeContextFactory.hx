package hex.compiletime.basic;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type.ClassType;
import hex.collection.ILocator;
import hex.collection.Locator;
import hex.compiletime.basic.vo.FactoryVOTypeDef;
import hex.compiletime.factory.FactoryUtil;
import hex.compiletime.factory.PropertyFactory;
import hex.core.ContextTypeList;
import hex.core.IApplicationContext;
import hex.core.ICoreFactory;
import hex.event.IDispatcher;
import hex.util.MacroUtil;
import hex.vo.ConstructorVO;
import hex.vo.MethodCallVO;
import hex.vo.PropertyVO;

using Lambda;

/**
 * ...
 * @author Francis Bourre
 */
class CompileTimeContextFactory 
	implements hex.core.IBuilder<BuildRequest>
	implements hex.compiletime.basic.IContextFactory 
	implements hex.collection.ILocatorListener<String, Dynamic>
{
	var _injectorContainerInterface : ClassType;
	var _moduleInterface 			: ClassType;
	
	
	var _isInitialized				: Bool;
	var _expressions 				: Array<Expr>;
	var _mappedTypes 				: Array<Expr>;
	var _injectedInto 				: Array<Expr>;
	
	var _contextDispatcher			: IDispatcher<{}>;
	var _moduleLocator				: Locator<String, String>;
	var _applicationContext 		: IApplicationContext;
	var _factoryMap 				: Map<String, FactoryVOTypeDef->Dynamic>;
	var _coreFactory 				: ICoreFactory;
	var _constructorVOLocator 		: Locator<String, ConstructorVO>;
	var _propertyVOLocator 			: Locator<String, Array<PropertyVO>>;
	var _methodCallVOLocator 		: Locator<String, MethodCallVO>;
	var _typeLocator 				: Locator<String, String>;
	var _dependencyChecker 			: MappingDependencyChecker;
	
	public function new( expressions : Array<Expr> )
	{
		this._expressions 					= expressions;
		this._isInitialized 				= false;
		this._injectorContainerInterface 	= MacroUtil.getClassType( Type.getClassName( hex.di.IInjectorContainer ) );
		this._moduleInterface 				= MacroUtil.getClassType( Type.getClassName( hex.module.IContextModule ) );
	}
	
	public function init( applicationContext : IApplicationContext ) : Void
	{
		if ( !this._isInitialized )
		{
			this._isInitialized = true;
			
			this._applicationContext 				= applicationContext;
			this._coreFactory 						= applicationContext.getCoreFactory();
			this._coreFactory.register( this._applicationContext.getName(), this._applicationContext );

			this._constructorVOLocator 				= new Locator();
			this._propertyVOLocator 				= new Locator();
			this._methodCallVOLocator 				= new Locator();
			this._typeLocator 						= new Locator();
			this._moduleLocator 					= new Locator();
			this._mappedTypes 						= [];
			this._injectedInto 						= [];
			this._factoryMap 						= hex.compiletime.basic.BasicCompileTimeSettings.factoryMap;
			this._dependencyChecker					= new MappingDependencyChecker( this._coreFactory, this._typeLocator );
			this._coreFactory.addListener( this );
		}
	}

	public function build( request : BuildRequest ) : Void
	{
		switch( request )
		{
			case PREPROCESS( vo ): this.preprocess( vo );
			case OBJECT( vo ): this.registerConstructorVO( vo );
			case PROPERTY( vo ): this.registerPropertyVO( vo );
			case METHOD_CALL( vo ): this.registerMethodCallVO( vo );
		}
	}
	
	public function finalize() : Void
	{
		this.dispatchAssemblingStart();
		this.buildAllObjects();
		this.buildAllProperties();
		this.callAllMethods();
		this.callModuleInitialisation();
		this.dispatchAssemblingEnd();
	}
	
	public function dispose() : Void
	{
		this._dependencyChecker = null;
		this._coreFactory.removeListener( this );
		this._coreFactory.clear();
		this._constructorVOLocator.release();
		this._propertyVOLocator.release();
		this._methodCallVOLocator.release();
		this._typeLocator.release();
		this._moduleLocator.release();
		this._factoryMap = hex.compiletime.basic.BasicCompileTimeSettings.factoryMap;
		this._mappedTypes = [];
		this._injectedInto = [];
	}
	
	public function getCoreFactory() : ICoreFactory
	{
		return this._coreFactory;
	}
	
	public function getTypeLocator() : ILocator<String, String>
	{
		return this._typeLocator;
	}
	
	public function dispatchAssemblingStart() : Void
	{
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.ASSEMBLING_START" );
		this._expressions.push( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );
	}
	
	public function dispatchAssemblingEnd() : Void
	{
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.ASSEMBLING_END" );
		this._expressions.push( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );
	}
	
	//
	public function preprocess( vo : hex.vo.PreProcessVO ) : Void
	{
		//We have only 1 preprocessor for now
		var e = hex.compiletime.factory.RuntimeParameterProcessor.process( this, vo );
		if ( e != null ) this._expressions.push( e );
	}
	
	public function registerPropertyVO( propertyVO : PropertyVO ) : Void
	{
		var id = propertyVO.ownerID;

		if ( this._propertyVOLocator.isRegisteredWithKey( id ) )
		{
			this._propertyVOLocator.locate( id ).push( propertyVO );
		}
		else
		{
			this._propertyVOLocator.register( id, [ propertyVO ] );
		}
	}
	
	//listen to CoreFactory
	public function onRegister( key : String, instance : Dynamic ) : Void
	{
		this.buildProperty( key );
	}

    public function onUnregister( key : String ) : Void  { }
	
	//
	public function registerConstructorVO( constructorVO : ConstructorVO ) : Void
	{
		this._constructorVOLocator.register( constructorVO.ID, constructorVO );
	}
	
	public function buildObject( id : String ) : Void
	{
		if ( this._constructorVOLocator.isRegisteredWithKey( id ) )
		{
			this.buildVO( this._constructorVOLocator.locate( id ), id );
			this._constructorVOLocator.unregister( id );
		}
	}
	
	public function buildAllObjects() : Void
	{
		this._constructorVOLocator.keys().map( this.buildObject );
		
		//Append to final expressions stack
		this._mappedTypes.map( this._expressions.push );
		this._injectedInto.map( this._expressions.push );
		
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.OBJECTS_BUILT" );
		this._expressions.push( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );
	}
	
	public function buildProperty( key : String ) : Void
	{
		if ( this._propertyVOLocator.isRegisteredWithKey( key ) )
		{
			this._propertyVOLocator.locate( key )
				.map( function( property ) this._expressions.push( macro @:mergeBlock ${ PropertyFactory.build( this, property ) } ) );
			this._propertyVOLocator.unregister( key );
		}
	}
	
	public function buildAllProperties() : Void
	{
		this._propertyVOLocator.keys().map( this.buildProperty );
	}
	
	public function registerMethodCallVO( methodCallVO : MethodCallVO ) : Void
	{
		this._methodCallVOLocator.register( "_" + hex.core.HashCodeFactory.getKey( methodCallVO ), methodCallVO );
	}
	
	public function callMethod( id : String ) : Void
	{
		var method 			= this._methodCallVOLocator.locate( id );
		var methodName 		= method.name;
		var cons 			= new ConstructorVO( null, ContextTypeList.FUNCTION, [ method.ownerID + "." + methodName ] );
		var func : Dynamic 	= this.buildVO( cons );
		var arguments 		= method.arguments;

		var idArgs = method.ownerID + "_" + method.name + "Args";
		var varIDArgs = macro $i { idArgs };
		var args = arguments.map( function(e) return this.buildVO( e ) );
		
		var varOwner = macro $p{ method.ownerID.split('.') };
		this._expressions.push( macro @:mergeBlock { $varOwner.$methodName( $a{ args } ); } );
	}

	public function callAllMethods() : Void
	{
		for ( key in this._methodCallVOLocator.keys() ) this.callMethod(  key );
		this._methodCallVOLocator.clear();
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.METHODS_CALLED" );
		this._expressions.push( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );
	}
	
	public function callModuleInitialisation() : Void
	{
		this._moduleLocator.values().map( function(moduleName) this._expressions.push( macro @:mergeBlock { $i{moduleName}.initialize(applicationContext); } ) );
		this._moduleLocator.clear();
		var messageType = MacroUtil.getStaticVariable( "hex.core.ApplicationAssemblerMessage.MODULES_INITIALIZED" );
		this._expressions.push( macro @:mergeBlock { applicationContext.dispatch( $messageType ); } );
	}

	public function getApplicationContext() return this._applicationContext;

	public function buildVO( constructorVO : ConstructorVO, ?id : String ) : Dynamic
	{
		constructorVO.shouldAssign 	= id != null;
		
		var type = constructorVO.className;
		var buildMethod : FactoryVOTypeDef->Dynamic = null;
		
		if ( this._factoryMap.exists( type ) )
		{
			buildMethod = this._factoryMap.get( type );
		}
		else if( constructorVO.ref != null )
		{
			buildMethod = hex.compiletime.factory.ReferenceFactory.build;
		}
		else
		{
			buildMethod = hex.compiletime.factory.ClassInstanceFactory.build;
		}
		
		var result = buildMethod( this._getFactoryVO( constructorVO ) );

		this._dependencyChecker.checkDependencies( constructorVO );

		if ( id != null )
		{
			this._typeLocator.register( id, constructorVO.type );
			_buildVO( constructorVO, id, result );
		}

		return result;
	}
	
	function _buildVO( constructorVO : ConstructorVO, id : String, result : Any ) : Void
	{
		this._tryToRegisterModule( constructorVO );
		this._parseInjectInto( constructorVO );
		this._parseMapTypes( constructorVO );

		this._expressions.push( macro @:mergeBlock { $result;  coreFactory.register( $v { id }, $i { id } ); } );
		this._coreFactory.register( id, result );
	}
	
	function _tryToRegisterModule( constructorVO : ConstructorVO ) : Void
	{
		if ( MacroUtil.implementsInterface( MacroUtil.getClassType( constructorVO.className, null, false ), _moduleInterface ) )
		{
			this._moduleLocator.register( constructorVO.ID, constructorVO.ID );
		}
	}
	
	function _parseInjectInto( constructorVO : ConstructorVO ) : Void
	{
		if ( constructorVO.injectInto && MacroUtil.implementsInterface( MacroUtil.getClassType( constructorVO.className, null, false ), _injectorContainerInterface ) )
		{
			//TODO throws an error if interface is not implemented
			this._injectedInto.push( 
				macro 	@:pos( constructorVO.filePosition )
						@:mergeBlock
						{ 
							__applicationContextInjector.injectInto( $i{ constructorVO.ID } ); 
						}
			);
		}
	}
	
	function _parseMapTypes( constructorVO : ConstructorVO ) : Void
	{
		if ( constructorVO.mapTypes != null )
		{
			var mapTypes = constructorVO.mapTypes;
			for ( mapType in mapTypes )
			{
				//Check if class exists
				FactoryUtil.checkTypeParamsExist( mapType, constructorVO.filePosition );
				
				//Remove whitespaces
				mapType = mapType.split( ' ' ).join( '' );
				
				//Map it
				this._mappedTypes.push( 
					macro 	@:pos( constructorVO.filePosition ) 
							@:mergeBlock 
							{
								__applicationContextInjector.mapClassNameToValue
								( $v{ mapType }, $i{ constructorVO.ID }, $v{ constructorVO.ID } 
								);
							}
				);
			}
		}
	}
	
	inline function _getFactoryVO( constructorVO : ConstructorVO = null ) : FactoryVOTypeDef
	{
		return { constructorVO : constructorVO, contextFactory : this };
	}
}
#end