# Nim for Visual Studio Code

[![Build Status](https://travis-ci.org/pragmagic/vscode-nim.svg?branch=master)](https://travis-ci.org/pragmagic/vscode-nim)

This extension adds language support for the Nim language to VS Code, including:

- Syntax Highlight (nim, nimble, nim.cfg)
- Code Completion
- Goto Definition
- Find References
- File outline
- Build-on-save
- Workspace symbol search

## Using

First, you will need to install Visual Studio Code `0.10`. 
In the command palette (`cmd-shift-p`) select `Install Extension` and choose `Nim`.  

The following tools are required for the extension:
* Nim compiler - http://nim-lang.org

_Note_: It is recommended to turn `Auto Save` on in Visual Studio Code (`File -> Auto Save`) when using this extension.  

### Options

The following Visual Studio Code settings are available for the Nim extension.  These can be set in user preferences (`cmd+,`) or workspace settings (`.vscode/settings.json`).
* `nim.buildOnSave` - perform build task from `tasks.json` file, to use this options you need declare build task according to [Tasks Documentaiton](https://code.visualstudio.com/docs/editor/taskshttps://code.visualstudio.com/docs/editor/tasks), for example:
	```json
	{
  	   "version": "0.1.0",
  	   "command": "nim",
	   "args": ["c", "-r", "module.nim"],
	   "options": {
	      "cwd": "${workspaceRoot}"
  	   },
	      "isShellCommand": true
  	   }
	}
	``` 
* `nim.lintOnSave` - perform the project check for errors on save
* `nim.project` - optional array of projects file, if nim.project not defined then all nim files will be used as separate project
* `nim.licenseString` - optional license text that will be inserted on nim file creation 

#### Example

```json
{
	"nim.buildOnSave": false,
	"nim.buildCommand": "c",
	"nim.lintOnSave": true,
	"nim.project": ["project.nim", "project2.nim"],
	"nim.licenseString": "# Copyright 2016.\n\n"
}
```

## TODO

* Rename support
* Documentation
* Quick info
* Code action for imports (suggest available modules to import)
* Debug support 

## History

### 0.5.4
* Added snippets [PR #18](https://github.com/pragmagic/vscode-nim/pull/18)
* Added a new nimsuggest
* Updated buildOnSave relative to tasks.json
* Fixed [Multiline comments syntax highlight.](https://github.com/pragmagic/vscode-nim/issues/11)
* Minor improvements and stability fixes 

### 0.5.2
* Added multiple projects support
* Fixed some hangs during indexing 

### 0.5.1
* Fixed #12 - Cannot compile nimsuggest 

### 0.5
* Refactored nimsuggest interaction to use EPC mode, removed nimble requirements
* Added info with qualified name for hovered element
* Improved suggest information

### 0.4.10
* Added test project support
* Improved nim check error parsing for macros and templates

### 0.4.9
* Improved database indexes
* Fixed multiline error in nim check
* Fixed nimsuggest problem with mixed case path in windows

### 0.4.6
* Fixed #9 - nimsuggest "attacks" (one process per nim file in workspace)
* Added type index persistence with NeDB

### 0.4.4
* Fixed #7 - Block comments / inline comments are not supported
* Fixed #8 - Terrible experience with clean install w/o nimsuggest

### 0.4.3
* Added workspace symbol search support 
* Rewrote nimsuggest handling to use TCP mode
* Added `nim.licenseString` for inserting default header in new nim files
* Updated `run project` command to run single file in non project mode 