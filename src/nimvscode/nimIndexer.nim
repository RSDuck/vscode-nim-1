import vscodeApi
import jsffi
import sequtils

import nimStatus
import nimSuggestExec

import flatdbnode

import jsNodeFs
import jsNodePath
import jsPromise
import asyncjs
import jsString
import jsre

import jsconsole

var dbVersion:cint = 5

var dbFiles:FlatDb
var dbTypes:FlatDb

type
    FileData = ref object of JsRoot
        file*:cstring
        timestamp*:int

    SymbolData = ref object
        ws*:cstring
        file*:cstring
        range_start*:VscodePosition
        range_end*:VscodePosition
        `type`*:cstring
        container*:cstring
        kind*:VscodeSymbolKind

proc findFile(file:cstring, timestamp:cint):Future[FileData] {.async.} =
    return dbFiles.queryOne(
            equal("file", file) and higherEqual("timestamp", timestamp)
        ).to(FileData)

proc vscodeKindFromNimSym(kind:cstring):VscodeSymbolKind =
    case $kind
    of "skConst": VscodeSymbolKind.constant
    of "skEnumField": VscodeSymbolKind.`enum`
    of "skForVar", "skLet", "skParam", "skVar": VscodeSymbolKind.variable
    of "skIterator": VscodeSymbolKind.`array`
    of "skLabel": VscodeSymbolKind.`string`
    of "skMacro", "skProc", "skResult", "skFunc": VscodeSymbolKind.function
    of "skMethod": VscodeSymbolKind.`method`
    of "skTemplate": VscodeSymbolKind.`interface`
    of "skType": VscodeSymbolKind.class
    else: VscodeSymbolKind.property

proc getFileSymbols*(
    file:cstring,
    useDirtyFile:bool,
    dirtyFileContent:cstring=""
):
    Future[seq[VscodeSymbolInformation]] {.async.} =
    console.log(
        "getFileSymbols - execnimsuggest - useDirtyFile",
        $(NimSuggestType.outline),
        file,
        useDirtyFile
    )
    var items = await nimSuggestExec.execNimSuggest(
        NimSuggestType.outline,
        file,
        0,
        0,
        useDirtyFile,
        dirtyFileContent
    )
    
    var symbols:seq[VscodeSymbolInformation] = @[]
    var exists: seq[cstring] = @[]

    var res = if items.toJs().to(bool): items else: @[]
    try:
        for item in res.filterIt(not (
            # skip let and var in proc and methods
            (it.suggest notIn ["skLet".cstring, "skVar"]) and
                it.containerName.contains(".")
        )):
            var toAdd = $(item.column) & ":" & $(item.line)
            if not any(exists, proc(x:cstring):bool = x == toAdd):
                exists.add(toAdd)
                var symbolInfo = vscode.newSymbolInformation(
                    item.symbolname,
                    vscodeKindFromNimSym(item.suggest),
                    item.`range`,
                    item.uri,
                    item.containerName
                )
                symbols.add(symbolInfo)
    except:
        var e = getCurrentException()
        console.error("getFileSymbols - failed", e)
        raise e
    return symbols

proc indexFile(file:cstring) {.async.} =
    var timestamp = fs.statSync(file).mtime.getTime().toJs().to(cint)
    var doc = await findFile(file, timestamp)
    if doc.isNil():
        var infos = await getFileSymbols(file, false)

        if infos.isNull() or infos.len == 0:
            return

        var folder = vscode.workspace.getWorkspaceFolder(vscode.uriFile(file))
        try:
            discard await (dbFiles.delete equal("file", file))
            if not folder.isNil():
                dbFiles.insert(FileData{file:file, timestamp:timestamp})
            else:
                console.log("indexFile - dbFiles - not in workspace")
        except:
            console.error("indexFile - dbFiles", getCurrentExceptionMsg(), getCurrentException())

        try:
            discard await dbTypes.delete equal("file", file)
            for i in infos:
                var folder = vscode.workspace.getWorkspaceFolder(i.location.uri)
                if folder.isNil():
                    console.log("indexFile - dbTypes - not in workspace", i.location.uri.fsPath)
                    continue

                dbTypes.insert(SymbolData{
                    ws: folder.uri.fsPath,
                    file: i.location.uri.fsPath,
                    range_start: i.location.`range`.start,
                    range_end: i.location.`range`.`end`,
                    `type`: i.name,
                    container: i.containerName,
                    kind: i.kind
                })
        except:
            console.error("indexFile - dbTypes", getCurrentExceptionMsg(), getCurrentException())

proc removeFromIndex(file:cstring):void =
    dbFiles.delete equal("file", file)

proc addWorkspaceFile*(file:cstring):void = discard indexFile(file)
proc removeWorkspaceFile*(file:cstring):void = removeFromIndex(file)
proc changeWorkspaceFile*(file:cstring):void = discard indexFile(file)

proc getDbName(name:cstring, version:cint):cstring =
    return name & "_" & $(version) & ".db"

proc cleanOldDb(basePath:cstring, name:cstring):void =
    var dbPath:cstring = path.join(basePath, (name & ".db"))
    if fs.existsSync(dbPath):
        fs.unlinkSync(dbPath)

    for i in 0..<dbVersion:
        var dbPath = path.join(basepath, getDbName(name, cint(i)))
        if fs.existsSync(dbPath):
            fs.unlinkSync(dbPath)

proc indexWorkspaceFiles*() {.async.} =
    var nimSuggestPath = nimSuggestExec.getNimSuggestPath()
    if nimSuggestPath.isNil() or nimSuggestPath == "":
        return;

    var urls = await vscode.workspace.findFiles("**/*.nim")
    showNimProgress("Indexing, file count: " & $(urls.len))
    for i, url in urls:
        var cnt = urls.len - 1

        if cnt mod 10 == 0:
            updateNimProgress("Indexing: " & $(cnt) & " of " & $(urls.len))
        
        console.log("indexing: ", i, url)
        await indexFile(url.fsPath)

    hideNimProgress()

proc initWorkspace*(extPath: cstring) {.async.} =
    # remove old version of indcies
    cleanOldDb(extPath, "files")
    cleanOldDb(extPath, "types")

    dbFiles = newFlatDb(path.join(extPath, getDbName("files", dbVersion)))
    dbTypes = newFlatDb(path.join(extPath, getDbName("types", dbVersion)))

    await indexWorkspaceFiles()
    discard dbFiles.processCommands()
    discard dbTypes.processCommands()

proc findWorkspaceSymbols*(
    query:cstring
):Future[seq[VscodeSymbolInformation]] {.async.} =
    var symbols:seq[VscodeSymbolInformation] = @[]
    try:
        var reg = newRegExp(query, r"i")
        var folders:seq[cstring] = vscode.workspace.workspaceFolders
            .mapIt(it.uri.fsPath)

        var docs = await dbTypes.query(
            qs().lim(100),
            oneOf("ws", folders) and matches("type", reg)
        )
        for d in docs:
            var doc = d.to(SymbolData)
            symbols.add(vscode.newSymbolInformation(
                doc.`type`,
                doc.kind,
                vscode.newRange(
                    vscode.newPosition(doc.range_start.line, doc.range_start.character),
                    vscode.newPosition(doc.range_end.line, doc.range_end.character)
                ),
                vscode.uriFile(doc.file),
                doc.container
            ))
    except:
        discard
    finally:
        return symbols

proc clearCaches*() {.async.} =
    if dbTypes != nil: await dbTypes.drop()
    if dbFiles != nil: await dbFiles.drop()
    await indexWorkspaceFiles()

proc onClose*() {.async.} =
    discard await allSettled(@[
        dbFiles.processCommands(),
        dbTypes.processCommands()
    ])

