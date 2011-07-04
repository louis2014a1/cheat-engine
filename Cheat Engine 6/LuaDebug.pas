unit LuaDebug;

{This unit will hold the debug_ specific lua functions}

{$mode delphi}

interface

uses
  Classes, SysUtils, newkernelhandler, debug, DebugHelper, DebuggerInterfaceAPIWrapper, lua, lualib, lauxlib, LuaHandler;

procedure initializeLuaDebug;

implementation

function debug_setLastBranchRecording(L: PLua_State): integer; cdecl;
var
  parameters: integer;
  newstate: boolean;
begin
  OutputDebugString('debug_setLastBranchRecording');
  result:=0;
  parameters:=lua_gettop(L);
  if parameters=1 then
  begin
    newstate:=lua_toboolean(L, -1);
    DBKDebug_SetStoreLBR(newstate);
  end;

  lua_pop(L, parameters);
end;

function debug_getMaxLastBranchRecord(L: PLua_State): integer; cdecl;
var
  max: integer;
begin
  result:=1;

  if CurrentDebuggerInterface<>nil then
    max:=CurrentDebuggerInterface.GetLastBranchRecords(nil)
  else
    max:=-1;

  lua_pop(L, lua_gettop(L));
  lua_pushinteger(L, max);
end;

function debug_getLastBranchRecord(L: PLua_State): integer; cdecl;
type TQwordArray=array [0..0] of qword;
  PQwordArray=^Tqwordarray;
var
  parameters: integer;
  value: ptruint;
  max: integer;
  index: integer;
  lbrbuf: PQwordArray;
begin
  result:=0;

  parameters:=lua_gettop(L);

  if parameters=1 then
  begin
    index:=lua_tointeger(L, -1);
    lua_pop(L, parameters);

    if CurrentDebuggerInterface<>nil then
    begin
      max:=CurrentDebuggerInterface.GetLastBranchRecords(nil);
      getmem(lbrbuf, max*sizeof(qword));
      try
        max:=CurrentDebuggerInterface.GetLastBranchRecords(lbrbuf);
        if index<=max then
          lua_pushinteger(L, lbrbuf[index]);

        result:=1;
      finally
        freemem(lbrbuf);
      end;
    end;

  end
  else
    lua_pop(L, parameters);
end;


procedure initializeLuaDebug;
begin
  lua_register(LuaVM, 'debug_setLastBranchRecording', debug_setLastBranchRecording);
  lua_register(LuaVM, 'debug_getMaxLastBranchRecord', debug_getMaxLastBranchRecord);
  lua_register(LuaVM, 'debug_getLastBranchRecord', debug_getLastBranchRecord);

end;

end.

