unit Main;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Dialogs, Snake.Types, Snake.Play;

const
  // Custom Windows message to defer game-over dialog off the timer's call stack.
  // PostMessage rather than SendMessage avoids re-entrant crashes when OnGameOver
  // fires synchronously from inside FGame.Step.
  WM_GAMEOVER_DEFERRED = WM_USER + $0100;

type
  TMainForm = class(TForm)
    tmrStep: TTimer;
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure tmrStepTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { Private declarations }
    // ── Game state ────────────────────────────────────────────────────────
    FGame:         TGame;           // Current game instance (recreated per session)
    FGaming:       Boolean;         // True while the step loop is running
    FScreenBuffer: TScreenBuffer;   // Logical grid — one cell colour per tile
    FMemBuffer:    TBitmap;         // Offscreen 32-bit bitmap for double-buffered rendering
    FRealFacing:   TSnakeFacing;    // Snake's last confirmed facing direction (sentinel check)

    // ── Rendering helpers ─────────────────────────────────────────────────
    procedure Draw;     // Copy accumulated frame from FMemBuffer → form canvas
    procedure Clear;    // Reset logical screen buffer to empty (white) cells

    // ── Gameplay lifecycle ────────────────────────────────────────────────
    procedure StartGame;       // Create fresh TGame and kick off the step timer
    procedure FinishGame;      // Halt the step timer — does NOT free objects

    // ── Callbacks & messages ──────────────────────────────────────────────
    procedure OnGameOverHandler;            // Synchronous callback fired by TGame on death
    procedure WMGameOverDeferred(var Msg: TMessage);  message WM_GAMEOVER_DEFERRED;   // Async handler: dialog / restart / exit // ⚠ message directive required so VCL routes
  public
    { Public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

// ── Rendering ────────────────────────────────────────────────────────────────

procedure TMainForm.Clear;
var
  i, j: Integer;
begin
  // Fill entire logical grid with white (empty-cell) colour
  for i := 0 to sWidth - 1 do
    for j := 0 to sHeight - 1 do
      FScreenBuffer[i, j] := bcWhite;
end;

procedure TMainForm.Draw;
var
  X, Y: Integer;
  CellColor: TColor;
  R: TRect;
begin
  // Guard against missing backing bitmap during early lifecycle or bad state
  if not Assigned(FMemBuffer) then Exit;

  // Lock GDI surface once for the whole frame — prevents tearing / partial renders
  FMemBuffer.Canvas.Lock;
  try
    // psClear pen ensures unfilled areas stay transparent (no flicker)
    FMemBuffer.Canvas.Pen.Style := psClear;

    // Paint every tile onto the offscreen bitmap
    for X := 0 to sWidth - 1 do
    begin
      for Y := 0 to sHeight - 1 do
      begin
        // bcBlack is rendered as near-black to distinguish snake head
        if FScreenBuffer[X,Y] = bcBlack then
          CellColor := $111111
        else
          CellColor := Colors[FScreenBuffer[X,Y]];

        // Compute pixel rectangle for this grid cell
        R.Left   := X * PixelPerBit;
        R.Top    := Y * PixelPerBit;
        R.Right  := R.Left + PixelPerBit;
        R.Bottom := R.Top + PixelPerBit;

        //Draw title payload
        FMemBuffer.Canvas.Brush.Color := CellColor;
        FMemBuffer.Canvas.Rectangle(R);
      end;
    end;

    // BitBlt the complete frame in one fast copy to the visible canvas
    Canvas.CopyRect(ClientRect, FMemBuffer.Canvas, ClientRect);
  finally
    FMemBuffer.Canvas.Unlock;
  end;
end;

// ── Gameplay lifecycle ───────────────────────────────────────────────────────
procedure TMainForm.StartGame;
begin
  // Tear down previous session — nil-safe via FreeAndNil
  if Assigned(FGame) then
    FreeAndNil(FGame);

  FGame            := TGame.Create(sWidth, sHeight);
  FGame.OnGameOver := OnGameOverHandler;  // Wire synchronous death callback
  FRealFacing      := FGame.Facing;

  FGaming := True;
  tmrStep.Enabled := True;  // Begin stepping
end;

procedure TMainForm.FinishGame;
begin
  // Silence the step loop and mark gameplay inactive.
  // Object lifetime is handled separately (see OnGameOverHandler / WMGameOverDeferred).
  tmrStep.Enabled := False;
  FGaming := False;
end;

procedure TMainForm.OnGameOverHandler;
begin
  // Fire synchronously from FGame.Step when collision is detected.
  // Must disable the timer here — otherwise the next timer tick could
  // operate on a dead or inconsistent game state.
  tmrStep.Enabled := False;
  FGaming := False;

  // Defer dialog creation off the Step() call stack to avoid re-entrant crashes.
  PostMessage(Handle, WM_GAMEOVER_DEFERRED, 0, 0);
end;

procedure TMainForm.WMGameOverDeferred(var Msg: TMessage);
begin
  // Drain any pending paint events first so the final game-over frame
  // is drawn before the modal dialog steals focus.
  Application.ProcessMessages;

  // Set true only long enough to let StartGame overwrite it — prevents
  // FormKeyDown or tmrStepTimer from entering their FGaming guard mid-dialog.
  FGaming := True;
  if messagedlg('Game Over! Want to play a new game?', mtWarning, [mbYes, mbNo], 0) = mrYes then
    StartGame   // Reuse path — creates new TGame, resets buffers internally
  else
    Close;      // Shut down the main form (triggers FormDestroy → cleanup)
end;

// ── Lifecycle ────────────────────────────────────────────────────────────────
procedure TMainForm.FormCreate(Sender: TObject);
begin
  // VCL built-in double buffering reduces flicker on repaint
  DoubleBuffered := True;

  // Size form to exact pixel dimensions of the logical grid
  ClientWidth := sWidth * PixelPerBit;
  ClientHeight := sHeight * PixelPerBit;

  // Allocate offscreen GDI bitmap for frame accumulation
  FMemBuffer := TBitmap.Create;
  FMemBuffer.PixelFormat := pf32bit; // Match native display depth
  FMemBuffer.SetSize(ClientWidth, ClientHeight);

  Clear;
  StartGame;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  // Ensure timer stops and FGaming clears before we tear down GDI resources.
  if FGaming or Assigned(FGame) then
    FinishGame;
  //Release drawing buffer
  FreeAndNil(FMemBuffer);     // Release bitmap & GDI handle
end;

// ── Input ────────────────────────────────────────────────────────────────────
procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Ignore keys when no active game session exists
  if not FGaming or not Assigned(FGame) then Exit;

  // Accept both WASD and arrow keys; reject 180° reversals using FRealFacing sentinel.
  case Key of
    Word('W'), VK_UP:
      if FRealFacing <> sfDown then FGame.Facing := sfUp;
    Word('S'), VK_DOWN:
      if FRealFacing <> sfUp then FGame.Facing := sfDown;
    Word('A'), VK_LEFT:
      if FRealFacing <> sfRight then FGame.Facing := sfLeft;
    Word('D'), VK_RIGHT:
      if FRealFacing <> sfLeft then FGame.Facing := sfRight;
  end;
end;

// ── Rendering triggers ───────────────────────────────────────────────────────
procedure TMainForm.FormPaint(Sender: TObject);
begin
  // OS window manager requests redraw (e.g. uncovering/restoring the form)
  Draw;
end;

procedure TMainForm.tmrStepTimer(Sender: TObject);
begin
  // Safety gate — bail if game was halted or game object already reclaimed
  if not FGaming or not Assigned(FGame) then exit;

  // Advance simulation one tick
  FGame.Step;

  // ┌───────────────────────────────────────────────────────────────────┐
  // │ CRITICAL: FGame may have been freed synchronously inside Step()   │
  // │ through the OnGameOver event chain. Always recheck Assigned()     │
  // │ after returning from Step before accessing properties/children.   │
  // └───────────────────────────────────────────────────────────────────│

  if Assigned(FGame) then
  begin
    FRealFacing := FGame.Facing;
    FGame.Display(FSCreenBuffer);
    Draw;
  end;
end;

end.

