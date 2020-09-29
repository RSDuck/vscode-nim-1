import jsffi, macros

type
    Map*[K,V] = ref MapObj[K,V]
    MapObj[K,V] {.importc.} = object of JsRoot

    # MapKeyIter*[K,V] = ref MapKeyIterObj[K,V]
    # MapKeyIterObj[K,V] {.importc.} = object of JsRoot

    # MapKeyIterResult*[K] = ref MapKeyIterResultObj[K]
    # MapKeyIterResultObj[K] {.importc.} = object of JsRoot
    #     value*:K
    #     done*:bool

    Buffer* = ref BufferObj
    BufferObj {.importc.} = object of JsRoot
        len* {.importcpp:"length".}:cint

    ProcessModule = ref ProcessModuleObj
    ProcessModuleObj {.importc.} = object of JsRoot
        env*:JsAssoc[cstring,cstring]
        platform*:cstring
    
    GlobalModule = ref GlobalModuleObj
    GlobalModuleObj {.importc.} = object of JsRoot

    Timeout* = ref object

var process* {.importc, nodecl.}:ProcessModule
var global* {.importc, nodecl.}:GlobalModule

# static
proc bufferConcat*(b:seq[Buffer]):Buffer {.importcpp: "(Buffer.concat(@))".}
proc newMap*[K,V]():Map[K,V] {.importcpp: "(new Map())".}
proc newBuffer*(size:cint):Buffer {.importcpp: "(new Buffer(@))".}
    ## TODO - mark as deprecated
proc bufferAlloc*(size:cint):Buffer {.importcpp: "(Buffer.alloc(@))".}

# global
proc setInterval*(g:GlobalModule, f:proc():void, t:cint):Timeout {.importcpp, discardable.}
proc clearInterval*(g:GlobalModule, t:Timeout):void {.importcpp.}

# Map
proc get*[K,V](m:Map[K,V], key:K):V {.importcpp.}
proc set*[K,V](m:Map[K,V], key:K, value:V):void {.importcpp.}
proc delete*[K,V](m:Map[K,V], key:K) {.importcpp.}
proc clear*[K,V](m:Map[K,V]) {.importcpp.}

iterator keys*[K,V](m:Map[K,V]):K =
    ## Yields the `keys` in a Map.
    var k:K
    {.emit: "for (let `k` of `m`.keys()) {".}
    yield k
    {.emit: "}".}

iterator values*[K,V](m:Map[K,V]):V =
    ## Yields the `keys` in a Map.
    var v:V
    {.emit: "for (let `v` of `m`.values()) {".}
    yield v
    {.emit: "}".}

iterator entries*[K,V](m:Map[K,V]):(K,V) =
    ## Yields the `entries` in a Map.
    var k:K
    var v:V
    {.emit: "for (let e of `m`.entries()) {".}
    {.emit: "  `k` = e[0]; `v` = e[1];".}
    yield (k,v)
    {.emit: "}".}

# Buffer
proc toString*(b:Buffer):cstring {.importcpp.}
proc toStringBase64*(b:Buffer):cstring
    {.importcpp:"(#.toString('base64'))".}
proc toStringUtf8*(b:Buffer, start:cint, stop:cint):cstring
    {.importcpp:"(#.toString('utf8', #, #))".}
proc slice*(b:Buffer, start:cint):Buffer {.importcpp.}

# JSON
proc jsonStringify*[T](val:T):cstring {.importcpp:"JSON.stringify(@)".}
proc toJsonStr(x: NimNode): NimNode {.compileTime.} =
    result = newNimNode(nnkTripleStrLit)
    result.strVal = astGenRepr(x)
template jsonStr*(x: untyped): untyped =
    ## Convert an expression to a JSON string directly, without quote
    result = toJsonStr(x)
proc jsonParse*(val:cstring):JsObject {.importcpp:"JSON.parse(@)".}
proc jsonParse*(val:cstring, T:typedesc):T {.importcpp:"JSON.parse(@)".}

# Misc
var numberMinValue* {.importc:"(Number.MIN_VALUE)", nodecl.}: cdouble
proc isJsArray*(a:JsObject):bool {.importcpp: "(# instanceof Array)".}