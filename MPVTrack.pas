unit MPVTrack;

// LibMPV track info helper classes
// Author: Edward G. (nbuyer@gmail.com)


interface

uses
  SysUtils, System.Generics.Collections, MPVClient, MPVNode;

type
  TMPVTrackType = (trkUnknown, trkVideo, trkAudio, trkSub);

  TMPVTrackInfo = class
  private
    m_nSrcID: Int64; // abs id
    m_eTrkType: TMPVTrackType;  //video/audio/sub
    m_nTrkID: Int64; // same type index
    m_sTitle: string; // track title
    m_sCodec: string; // codec
    m_sLang: string; // lang id such as "eng"
    m_nBitrate: Int64; // bitrate if avail
    m_nVal1: Int64;  // width / channel count
    m_nVal2: Int64;  // height / samplerate
    m_fVal3: Double; // fps
  public
    function LoadFromNode(cNode: TMPVNode): Boolean;
    procedure Clear;
    procedure Assign(cTI: TMPVTrackInfo);
  public
    property TrackType: TMPVTrackType read m_eTrkType;
    property SrcID: Int64 read m_nSrcID;
    property TrackID: Int64 read m_nTrkID;
    property Title: string read m_sTitle;
    property LangID: string read m_sLang;
    property Codec: string read m_sCodec;

    property VideoWidth: Int64 read m_nVal1;
    property VideoHeight: Int64 read m_nVal2;
    property VideoFPS: Double read m_fVal3;
    property BitRate: Int64 read m_nBitrate;
    property AudioChannel: Int64 read m_nVal1;
    property AudioSampleRate: Int64 read m_nVal2;
  end;

  TMPVTrackList = class(TObjectList<TMPVTrackInfo>)
  public
    constructor Create;
    procedure Assign(cTL: TMPVTrackList; eFilterType: TMPVTrackType = trkUnknown);
    function LoadFromNode(cNode: TMPVNode): Boolean;
    function FindTrack(eType: TMPVTrackType; id: Int64): TMPVTrackInfo;
  end;

implementation

{ TMPVTrackInfo }

procedure TMPVTrackInfo.Assign(cTI: TMPVTrackInfo);
begin
  m_nSrcID := cTI.SrcID;
  m_eTrkType := cTI.TrackType;
  m_nTrkID := cTI.m_nTrkID;
  m_sTitle := cTI.Title;
  m_sCodec := cTI.Codec;
  m_sLang := cTI.LangID;
  m_nBitrate := cTI.BitRate;
  m_nVal1 := cTI.VideoWidth;
  m_nVal2 := cTI.VideoHeight;
  m_fVal3 := cTI.VideoFPS;
end;

procedure TMPVTrackInfo.Clear;
begin
  m_nSrcID := 0;
  m_eTrkType := trkUnknown;
  m_nTrkID := 0;
  m_sTitle := '';
  m_sCodec := '';
  m_sLang := '';
  m_nBitrate := 0;
  m_nVal1 := 0;
  m_nVal2 := 0;
  m_fVal3 := 0.0;
end;

function TMPVTrackInfo.LoadFromNode(cNode: TMPVNode): Boolean;
var
  i: Integer;
  cN: TMPVNode;
  sKey, s: string;
begin
  if cNode.Fmt<>MPV_FORMAT_NODE_MAP then
  begin
    Result := False;
    Exit;
  end;
  Result := True;
  Clear;

  for i := 0 to cNode.Nodes.Count-1 do
  begin
    cN := cNode.Nodes.GetNode(i);
    sKey := cNode.Nodes[i];
    if sKey='id' then
      m_nTrkID := cN.AsInt64
    else if sKey='type' then
      begin
        s := AnsiLowercase(cN.AsString);
        if s='video' then
          m_eTrkType := trkVideo
        else if s='audio' then
          m_eTrkType := trkAudio
        else if s='sub' then
          m_eTrkType := trkSub
        else m_eTrkType := trkUnknown;
      end
    else if sKey='src-id' then
      m_nSrcID := cN.AsInt64
    else if sKey='title' then
      m_sTitle := cN.AsString
    else if sKey='lang' then
      m_sLang := cN.AsString
    else if sKey='codec' then
      m_sCodec := cN.AsString
    else if sKey='demux-w' then
      m_nVal1 := cN.AsInt64
    else if sKey='demux-h' then
      m_nVal2 := cN.AsInt64
    else if sKey= 'demux-fps' then
      m_fVal3 := cN.AsDouble
    else if sKey='demux-channel-count' then
      m_nVal1 := cN.AsInt64
    else if sKey='demux-samplerate' then
      m_nVal2 := cN.AsInt64
    else if sKey='demux-bitrate' then
      m_nBitrate := cN.AsInt64;
  end;
end;

{ TMPVTrackList }

procedure TMPVTrackList.Assign(cTL: TMPVTrackList; eFilterType: TMPVTrackType);
var
  cTrk, cNewTrk: TMPVTrackInfo;
begin
  Clear;
  for cTrk in cTL do
  begin
    if (eFilterType=trkUnknown) or (cTrk.TrackType=eFilterType) then
    begin
      cNewTrk := TMPVTrackInfo.Create;
      cNewTrk.Assign(cTrk);
      if Add(cNewTrk)<0 then cNewTrk.Free;
    end;
  end;
end;

constructor TMPVTrackList.Create;
begin
  inherited Create(True);
end;

function TMPVTrackList.FindTrack(eType: TMPVTrackType; id: Int64): TMPVTrackInfo;
var
  cTrk: TMPVTrackInfo;
begin
  for cTrk in List do
  begin
    if cTrk.TrackType=eType then
      if cTrk.TrackID=id then
      begin
        Result := cTrk;
        Exit;
      end;
  end;
  Result := nil;
end;

function TMPVTrackList.LoadFromNode(cNode: TMPVNode): Boolean;
var
  i: Integer;
  cN: TMPVNode;
  cTrk: TMPVTrackInfo;
begin
  if cNode.Fmt<>MPV_FORMAT_NODE_ARRAY then
  begin
    Result := False;
    Exit;
  end;

  Clear;
  Result := True;

  for i := 0 to cNode.Nodes.Count-1 do
  begin
    cN := cNode.Nodes.GetNode(i);
    cTrk := TMPVTrackInfo.Create;
    if cTrk.LoadFromNode(cN) then
    begin
      if Add(cTrk)<0 then cTrk.Free;
    end else
      cTrk.Free;
  end;
end;

end.
