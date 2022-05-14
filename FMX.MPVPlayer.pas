unit FMX.MPVPlayer;

// MPV player and display control for FireMonkey
// Author: Edward G. (nbuyer@gmail.com)

// Currently ONLY support Windows

interface

uses
  SysUtils, Classes, Types,
  FMX.Types, FMX.Controls, Messaging, FMX.Forms, FMX.Platform,
{$IFDEF MSWINDOWS}
  Windows, FMX.Platform.Win, Messages,
{$ENDIF}
  MPVClient, MPVBasePlayer;

const
  MIN_FLOAT_VALUE = 0.000001;

type
  TMPVFMXPlayer = class;

  // Copied from TMediaPlayerControl
  TMPVPlayerControl = class(TControl)
  private
  {$IFDEF MSWINDOWS}
    m_hWnd: HWND;
  {$ENDIF}
    m_cMediaPlayer: TMPVFMXPlayer;
    [Weak] m_cSavedParent: TFmxObject;
    procedure FormHandleAfterCreated(const Sender: TObject; const Msg: Messaging.TMessage);
    procedure FormHandleBeforeDestroyed(const Sender: TObject; const Msg: Messaging.TMessage);
  protected
    procedure AncestorVisibleChanged(const Visible: Boolean); override;
    procedure ParentChanged; override;
    procedure DoAbsoluteChanged; override;
    procedure Move; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateParent(AOwner: TComponent; h: TWindowHandle);
    destructor Destroy; override;
    procedure InitWindowHandle(h: TWindowHandle);
    procedure DestroyWindowHandle;

    function GetWindowHandle: string;
    procedure SetMediaPlayer(cPlayer: TMPVFMXPlayer);
    procedure UpdateMedia;
    function GetParentWindowHandle: string;
  public
    property Left: Single read GetLeft;
    property Top: Single read GetTop;
  published
    property Size;
    property Align;
    property Anchors;
    property Height;
    property Padding;
    property MediaPlayer: TMPVFMXPlayer read m_cMediaPlayer write SetMediaPlayer;
    property Margins;
    property Position;
    property Visible default True;
    property Width;
  end;

  TMPVFMXPlayer = class(TMPVBasePlayer)
  protected
    m_rLastRect: TRectF;
    m_cCtrl: TMPVPlayerControl;
  public
    procedure SetControl(const Value: TMPVPlayerControl);
    procedure UpdateFromControl(bForce: Boolean);
  end;

// Use Result.MediaPlayer to get the player object
function CreateMPVFMXPlayerControl(cForm: TCommonCustomForm;
  cParent: TControl; eOnMouseDown: TMouseEvent): TMPVPlayerControl;
procedure SetMPVFMXPlayerControlParent(cCtrl: TMPVPlayerControl; cParent: TControl);
function GetScreenScale: Single;

implementation

function GetScreenScale: Single;
var
  ScreenService: IFMXScreenService;
begin
  Result := 1;
  if TPlatformServices.Current.SupportsPlatformService (IFMXScreenService, IInterface(ScreenService)) then
    Result := ScreenService.GetScreenScale;
end;

procedure SetMPVFMXPlayerControlParent(cCtrl: TMPVPlayerControl; cParent: TControl);
begin
  cCtrl.Parent := nil;
  cCtrl.Align := TAlignLayout.None;
  cCtrl.Position.X := -1; // incorrect one to make FMX to change
  cCtrl.Position.Y := -1;
  cCtrl.Parent := cParent;
  cCtrl.Size.Width := cParent.Width;
  cCtrl.Size.Height := cParent.Height;
  cCtrl.Align := TAlignLayout.Client;
  cCtrl.Visible := True;
end;

function CreateMPVFMXPlayerControl(cForm: TCommonCustomForm;
  cParent: TControl; eOnMouseDown: TMouseEvent): TMPVPlayerControl;
var
  cCtrl: TMPVPlayerControl;
  cPlayer: TMPVFMXPlayer;
begin
  cPlayer := TMPVFMXPlayer.Create;
  cCtrl := TMPVPlayerControl.CreateParent(cForm, cForm.Handle);
  cPlayer.SetControl(cCtrl);
  cCtrl.OnMouseDown := eOnMouseDown;
  SetMPVFMXPlayerControlParent(cCtrl, cParent);
  Result := cCtrl;
end;

{ TMPVPlayerControl }

procedure TMPVPlayerControl.AncestorVisibleChanged(const Visible: Boolean);
begin
  inherited;
  UpdateMedia;
end;

constructor TMPVPlayerControl.Create(AOwner: TComponent);
begin
  inherited;
  if not (csDesigning in ComponentState) then
  begin
    System.Messaging.TMessageManager.DefaultManager.SubscribeToMessage(TAfterCreateFormHandle, FormHandleAfterCreated);
    TMessageManager.DefaultManager.SubscribeToMessage(TBeforeDestroyFormHandle, FormHandleBeforeDestroyed);
  end;
  InitWindowHandle(nil);
end;

constructor TMPVPlayerControl.CreateParent(AOwner: TComponent; h: TWindowHandle);
begin
  inherited Create(AOwner);
  if not (csDesigning in ComponentState) then
  begin
    TMessageManager.DefaultManager.SubscribeToMessage(TAfterCreateFormHandle, FormHandleAfterCreated);
    TMessageManager.DefaultManager.SubscribeToMessage(TBeforeDestroyFormHandle, FormHandleBeforeDestroyed);
  end;
  InitWindowHandle(h);
end;

destructor TMPVPlayerControl.Destroy;
begin
  if m_cMediaPlayer <> nil then
    m_cMediaPlayer.SetControl(nil);
  DestroyWindowHandle;
  if not (csDesigning in ComponentState) then
  begin
    TMessageManager.DefaultManager.Unsubscribe(TBeforeDestroyFormHandle, FormHandleBeforeDestroyed);
    TMessageManager.DefaultManager.Unsubscribe(TAfterCreateFormHandle, FormHandleAfterCreated);
  end;
  inherited;
end;

procedure TMPVPlayerControl.DoAbsoluteChanged;
begin
  inherited;
  UpdateMedia;
end;

procedure TMPVPlayerControl.FormHandleAfterCreated(const Sender: TObject;
  const Msg: Messaging.TMessage);

  function IsMediaRootForm(const AForm: TObject): Boolean;
  begin
    Result := (m_cSavedParent = AForm) or
              (m_cSavedParent <> nil) and (m_cSavedParent.Root <> nil) and (m_cSavedParent.Root.GetObject = AForm) and (AForm is TCommonCustomForm);
  end;

begin
  if (m_cMediaPlayer <> nil) and IsMediaRootForm(Sender) then
  begin
    Parent := m_cSavedParent;
    UpdateMedia;
  end;
end;

procedure TMPVPlayerControl.FormHandleBeforeDestroyed(const Sender: TObject;
  const Msg: Messaging.TMessage);

  function IsMediaRootForm(const AForm: TObject): Boolean;
  begin
    Result := (Root <> nil) and (Root.GetObject = AForm) and (AForm is TCommonCustomForm);
  end;

begin
  // Ignores destroying handle of other forms
  if not IsMediaRootForm(Sender) then
    Exit;

  m_cSavedParent := Parent;
  Parent := nil;
end;

{$IFDEF MSWINDOWS}
procedure TMPVPlayerControl.DestroyWindowHandle;
begin
  DestroyWindow(m_hWnd);
end;

function TMPVPlayerControl.GetParentWindowHandle: string;
var
  fo: TFmxObject;
begin
  Result := '';
  fo := Parent;
  while fo<>nil do
  begin
    if fo is TCommonCustomForm then
    begin
      Result := IntToStr(FmxHandleToHWND(TCommonCustomForm(fo).Handle));
      Exit;
    end;
    fo := fo.Parent;
  end;
end;

function TMPVPlayerControl.GetWindowHandle: string;
begin
  Result := IntToStr(m_hWnd);
end;

type
  TWinProc = function (h: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

function MPVCtrlWndProc(h: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  hp: HWND;
  p: TWinProc;
begin
  case uMsg of
  WM_KEYFIRST..WM_KEYLAST, // key first to last
  WM_MOUSEFIRST..WM_MOUSELAST: // mouse first to last, WM_LBUTTONDOWN=$201
    begin
      // forward to parent window (should be a form/app), so that we can get mouse clicks
      hp := GetParent(h);
      //if hp<>GetDeskTopWindow() then
      begin
        p := TWinProc(GetWindowLong(hp, GWL_WNDPROC));
        if Assigned(p) then
        begin
//          if uMsg=WM_LBUTTONDOWN then
//            Sleep(0);  // debug use
          Result := p(hp, uMsg, wParam, lParam);
          Exit;
        end;
      end;
    end;
  end;
  Result := DefWindowProc(h, uMsg, wParam, lParam);
end;

procedure TMPVPlayerControl.InitWindowHandle(h: TWindowHandle);
const
  CLASS_NAME = 'TMPVCtrl';
var
  WindowClass: TWndClass;
  hwin: HWND;
begin
  if not GetClassInfo(hInstance, CLASS_NAME, WindowClass) then
  begin
    FillChar(WindowClass, SizeOf(WindowClass), 0);
    WindowClass.Style := CS_HREDRAW or CS_VREDRAW;
    //@DefWindowProc; Use our wndproc to forward kb/mouse messages
    WindowClass.lpfnWndProc := @MPVCtrlWndProc;
    WindowClass.cbClsExtra := 0;
    WindowClass.cbWndExtra := 0;
    WindowClass.hInstance := hInstance;
    WindowClass.hCursor := LoadCursorW(0, PChar(IDC_ARROW));
    WindowClass.hbrBackground := GetStockObject(NULL_BRUSH);
    WindowClass.lpszMenuName := nil;
    WindowClass.lpszClassName := CLASS_NAME;
    if Windows.RegisterClass(WindowClass) = 0 then
      RaiseLastOSError;
  end;
  if h<>nil then
  begin
    hwin := FmxHandleToHWND(h);
  end else
  begin
    hwin := ApplicationHWND;
  end;
  m_hWnd := CreateWindowEx(0, //WS_EX_CONTROLPARENT
    WindowClass.lpszClassName, nil,
    WS_CLIPSIBLINGS or WS_CLIPCHILDREN or WS_CHILDWINDOW,
    0, 0, 0, 0, hwin, 0, hInstance, nil);
  SetWindowPos(m_hWnd, 0, 0, 0, 0, 0, SWP_NOMOVE+SWP_NOSIZE+SWP_NOACTIVATE);
  ShowWindow(m_hWnd, SW_HIDE);
end;
{$ENDIF MSWINDOWS}

procedure TMPVPlayerControl.Move;
begin
  inherited;
  UpdateMedia;
end;

procedure TMPVPlayerControl.ParentChanged;
begin
  inherited;
  UpdateMedia;
end;

procedure TMPVPlayerControl.Resize;
begin
  inherited;
  UpdateMedia;
end;

procedure TMPVPlayerControl.SetMediaPlayer(cPlayer: TMPVFMXPlayer);
begin
  if m_cMediaPlayer <> cPlayer then
  begin
    if m_cMediaPlayer <> nil then
      m_cMediaPlayer.SetControl(nil);
    m_cMediaPlayer := cPlayer;
    if m_cMediaPlayer <> nil then
      m_cMediaPlayer.SetControl(Self);
  end;
end;

procedure TMPVPlayerControl.UpdateMedia;
begin
  if (m_cMediaPlayer <> nil) then
    m_cMediaPlayer.UpdateFromControl(False);
end;

{ TMPVFMXPlayer }

procedure TMPVFMXPlayer.SetControl(const Value: TMPVPlayerControl);
begin
  m_cCtrl := Value;
  if Assigned(m_cCtrl) then
  begin
    m_cCtrl.SetMediaPlayer(Self);
  end;
end;

procedure TMPVFMXPlayer.UpdateFromControl(bForce: Boolean);
{$IFDEF MSWINDOWS}
// Ref from TWindowsMedia
var
  Bounds: TRectF;
  ScaleRatio: Single;
  hWin, hParent: HWND;
  bUpd: Boolean;

begin
  if not Assigned(m_cCtrl) then Exit;

  // Platform
  hWin := StrToIntDef(m_cCtrl.GetWindowHandle, 0);
  if hWin<>0 then
  begin
    if (Assigned(m_cCtrl)) and (m_cCtrl.GetParentWindowHandle<>'') then
    begin
      ScaleRatio := GetScreenScale;
      Bounds := TRectF.Create(0, 0, m_cCtrl.AbsoluteWidth * ScaleRatio,
        m_cCtrl.AbsoluteHeight * ScaleRatio);
      Bounds.Fit(RectF(0, 0, m_cCtrl.AbsoluteWidth * ScaleRatio,
        m_cCtrl.AbsoluteHeight * ScaleRatio));
      Bounds.Offset(m_cCtrl.GetAbsoluteRect.Left * ScaleRatio,
        m_cCtrl.GetAbsoluteRect.Top * ScaleRatio);

      if bForce then
      begin
        bUpd := True;
        if m_rLastRect.EqualsTo(Bounds, MIN_FLOAT_VALUE) then
        begin
          // Make not equal. Sometimes window does not show up even you call
          // SetWindowPos() with the same Bounds
          Bounds.Top := Bounds.Top+1;
        end;
      end else
      begin
        bUpd := False;
        // Moved? Resize event may be called multiple times when aligning,
        // some of them should be ignored such as 0/neg values
        with Bounds do
        if (Top>-MIN_FLOAT_VALUE) and (Left>-MIN_FLOAT_VALUE) and
          (Bottom-Top>MIN_FLOAT_VALUE) and (Right-Left>MIN_FLOAT_VALUE) then
          if not m_rLastRect.EqualsTo(Bounds, MIN_FLOAT_VALUE) then
             bUpd := True;
      end;

      if bUpd then
      begin
        m_rLastRect := Bounds; // save last
        hParent := StrToIntDef(m_cCtrl.GetParentWindowHandle, 0);
        if GetParent(hWin)<>hParent then
          SetParent(hWin, hParent);
        SetWindowPos(hWin, HWND_TOP, Bounds.Round.Left, Bounds.Round.Top,
          Bounds.Round.Width, Bounds.Round.Height, SWP_SHOWWINDOW);
        if bForce or (not IsWindowVisible(hWin)) then
          ShowWindow(hWin, SW_SHOW);
      end else
      begin
        if not IsWindowVisible(hWin) then
          ShowWindow(hWin, SW_SHOW);
      end;
    end else
    begin
      SetParent(hWin, ApplicationHWND);
      ShowWindow(hWin, SW_HIDE)
    end;
  end;
end;
{$ELSE}
begin
  // TODO
end;
{$ENDIF MSWINDOWS}


end.
