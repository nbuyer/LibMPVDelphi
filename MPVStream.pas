unit MPVStream;

{
  MPV Stream callback object using TStream
  Author: Edward G. (nbuyer@gmail.com)
}

interface

uses
  Classes, SysUtils, MPVClient, MPVStreamCB;

type
  // MPV stream object
  TMPVStream = class(TStream)
  private
    m_cStream: TStream; // actual TStream object
    m_bOwnStream: Boolean; // free this object
  public
    constructor Create(cStream: TStream; bOwnStream: Boolean);
    destructor Destroy; override;
    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    procedure Cancel; virtual;
  end;

  // Override CreateStream() to create a TMPVStream
  TMPVStreamProvider = class
  public
    // sURI contains the full URL(including protocol) of LoadFile()
    function CreateStream(const sURI: string): TMPVStream; virtual; abstract;
  end;

// libmpv stream callbacks
function MPVStreamOpen(user_data: Pointer; curi: PMPVChar; info: P_mpv_stream_cb_info): MPVInt; cdecl;
function MPVStreamRead(cookie: Pointer; buf: PMPVChar; size: MPVUInt64): MPVInt64; cdecl;
function MPVStreamSeek(cookie: Pointer; Offset: MPVInt64): MPVInt64; cdecl;
function MPVStreamSize(cookie: Pointer): MPVInt64; cdecl;
procedure MPVStreamClose(cookie: Pointer); cdecl;
procedure MPVStreamCancel(cookie: Pointer); cdecl;

// Register stream handling to protocol for a MPV instance
// ctx: TMPVBasePlayer.Handle
// protocol: such as 'myprot'
// cProvider: new a TMPVStreamProvider class and implement CreateStream()
function RegisterMPVStream(ctx: PMPVHandle; const protocol: string;
  cProvider: TMPVStreamProvider): MPVInt;

implementation

procedure TMPVStream.Cancel;
begin
  // NULL
end;

constructor TMPVStream.Create(cStream: TStream; bOwnStream: Boolean);
begin
  inherited Create;
  m_cStream := cStream;
  m_bOwnStream := bOwnStream; // should I free the object?
end;

destructor TMPVStream.Destroy;
begin
  if m_bOwnStream then m_cStream.Free;
  inherited Destroy;
end;

function TMPVStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := m_cStream.Read(Buffer, Count);
end;

function TMPVStream.Seek(Offset: Longint; Origin: Word): Longint;
begin
  Result := m_cStream.Seek(Offset, Origin);
end;

// libmpv read
function MPVStreamRead(cookie: Pointer; buf: PMPVChar; size: MPVUInt64): MPVInt64; cdecl;
var
  Stream: TMPVStream;
begin
  Stream := TMPVStream(cookie);
  Result := Stream.Read(buf^, size);
end;

// libmpv seek
function MPVStreamSeek(cookie: Pointer; Offset: MPVInt64): MPVInt64; cdecl;
var
  Stream: TMPVStream;
begin
  Stream := TMPVStream(cookie);
  Result := Stream.Seek(Offset, soFromBeginning);
end;

// libmpv get size
function MPVStreamSize(cookie: Pointer): MPVInt64; cdecl;
var
  Stream: TMPVStream;
  nCur: Int64;
begin
  Stream := TMPVStream(cookie);
  nCur := Stream.Seek(Int64(0), soCurrent);
  Result := Stream.Seek(Int64(0), soFromEnd);
  Stream.Seek(nCur, soFromBeginning);
end;

// libmpv close
procedure MPVStreamClose(cookie: Pointer); cdecl;
var
  Stream: TMPVStream;
begin
  Stream := TMPVStream(cookie);
  FreeAndNil(Stream);
end;

// libmpv cancel
procedure MPVStreamCancel(cookie: Pointer); cdecl;
var
  Stream: TMPVStream;
begin
  Stream := TMPVStream(cookie);
  Stream.Cancel;
end;

// open stream, will be called after LoadFile()
function MPVStreamOpen(user_data: Pointer; curi: PMPVChar; info: P_mpv_stream_cb_info): MPVInt; cdecl;
var
  cMStm: TMPVStream;
begin
  // curi is current full URI including 'myprot://'
  try
    cMStm := TMPVStreamProvider(user_data).CreateStream(string(curi));
  except
    cMStm := nil;
  end;
  if cMStm=nil then
  begin
    Result := MPV_ERROR_LOADING_FAILED;
    Exit;
  end;
  info^.cookie := cMStm;
  info^.read_fn := @MPVStreamRead;
  info^.seek_fn := @MPVStreamSeek;
  info^.size_fn := @MPVStreamSize;
  info^.close_fn := @MPVStreamClose;
  info^.cancel_fn := @MPVStreamCancel;
  Result := MPV_ERROR_SUCCESS;
end;

function RegisterMPVStream(ctx: PMPVHandle; const protocol: string;
  cProvider: TMPVStreamProvider): MPVInt;
var
  sProc: AnsiString;
begin
{$IFDEF MPV_DYNAMIC_LOAD}
  if Assigned(mpv_stream_cb_add_ro) then
{$ENDIF}
  begin
    sProc := AnsiString(protocol);  // such as 'myprot'
    Result := mpv_stream_cb_add_ro(ctx, PAnsiChar(sProc), cProvider, @MPVStreamOpen);
  end
{$IFDEF MPV_DYNAMIC_LOAD}
  else
    Result := MPV_ERROR_UNINITIALIZED
{$ENDIF}
;
end;

end.
