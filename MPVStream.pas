unit MPVStream;

{
  MPV Stream callback object using TStream
  Author: Edward G. (nbuyer@gmail.com)

  TODO: test
}

interface

uses
  Classes, SysUtils, MPVClient, MPVStreamCB;

type

  // MPV stream object
  TMPVStream = class(TStream)
  private
    m_cStream: TStream; // actual TStream object
  public
    constructor Create(AStream: TStream);
    destructor Destroy; override;

    function Read(var Buffer; Count: Longint): Longint; override;
    function Seek(Offset: Longint; Origin: Word): Longint; override;
    procedure Cancel; virtual;
  end;


// libmpv stream callbacks
function MPVStreamRead(cookie: Pointer; buf: PMPVChar; size: MPVUInt64): MPVInt64; cdecl;
function MPVStreamSeek(cookie: Pointer; offset: MPVInt64): MPVInt64; cdecl;
function MPVStreamSize(cookie: Pointer): MPVInt64; cdecl;
procedure MPVStreamClose(cookie: Pointer); cdecl;
procedure MPVStreamCancel(cookie: Pointer); cdecl;

// Register stream handling to protocol
function RegisterMPVStream(ctx: PMPVHandle; const protocol: string; cStm: TStream): MPVInt;

implementation

procedure TMPVStream.Cancel;
begin
  // NULL
end;

constructor TMPVStream.Create(AStream: TStream);
begin
  inherited Create;
  m_cStream := AStream;
end;

destructor TMPVStream.Destroy;
begin
  m_cStream.Free;
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
function MPVStreamSeek(cookie: Pointer; offset: MPVInt64): MPVInt64; cdecl;
var
  Stream: TMPVStream;
begin
  Stream := TMPVStream(cookie);
  Result := Stream.Seek(offset, soFromBeginning);
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
  Stream.Free;
end;

// libmpv cancel
procedure MPVStreamCancel(cookie: Pointer); cdecl;
var
  Stream: TMPVStream;
begin
  Stream := TMPVStream(cookie);
  Stream.Cancel;
end;

function RegisterMPVStream(ctx: PMPVHandle; const protocol: string;
  cStm: TStream): MPVInt;
var
  sProc: AnsiString;
  cbData: mpv_stream_cb_info;
begin
  if Assigned(mpv_stream_cb_add_ro) then
  begin
    sProc := protocol;
    FillChar(cbData, sizeof(cbData), 0);
    cbData.cookie := cStm;
    cbData.read_fn := @MPVStreamRead;
    cbData.seek_fn := @MPVStreamSeek;
    cbData.size_fn := @MPVStreamSize;
    cbData.close_fn := @MPVStreamClose;
    cbData.cancel_fn := @MPVStreamCancel;
    Result := mpv_stream_cb_add_ro(ctx, PAnsiChar(sProc), cStm, @cbData);
  end else
    Result := MPV_ERROR_UNINITIALIZED;
end;

end.
