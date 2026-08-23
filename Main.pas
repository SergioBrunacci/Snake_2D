unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, StdCtrls,
  Snake.Types, Snake.Play, ExtCtrls, Vcl.Dialogs;

type
  TMainForm = class(TForm)
    tmrStep: TTimer;
    procedure FormPaint(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure tmrStepTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GameError(const MSG: string);
    procedure GameOver;
  private
    { Private declarations }
  public
    { Public declarations }
    Game: TGame;
    Gaming: Boolean;
    ScreenBuffer: TScreenBuffer;
    MemBuffer: TBitmap;
    RealFacing: TSnakeFacing;
    FPS: Integer;
    DisplayFPS: Integer;
    procedure Draw;
    procedure Clear;
    procedure StartGame;
    procedure FinishGame;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

procedure TMainForm.Clear;
var
  i, j: Integer;
begin
  for i := 0 to sWidth - 1 do
    for j := 0 to sHeight - 1 do
      ScreenBuffer[i, j] := bcWhite;
end;

procedure TMainForm.Draw;
var
  i, j: Integer;
begin
  with MemBuffer do
    for i := 0 to sWidth - 1 do
      for j := 0 to sHeight - 1 do
      begin
        if ScreenBuffer[i, j] = bcBlack then
          Canvas.Pen.Color := $111111
        else
          Canvas.Pen.Color := Colors[ScreenBuffer[i, j]];
        Canvas.Brush.Color := Colors[ScreenBuffer[i, j]];
        Canvas.Rectangle(i * PixelPerBit, j * PixelPerBit, (i + 1) * PixelPerBit, (j + 1) *
          PixelPerBit);
      end;
  Canvas.CopyRect(Rect(0, 0, ClientWidth, ClientHeight), MemBuffer.Canvas, Rect(0, 0, ClientWidth, ClientHeight));
end;

procedure TMainForm.FinishGame;
begin
  Gaming := False;
  Game.Free;
  tmrStep.Enabled := False;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  ClientWidth := sWidth * PixelPerBit;
  ClientHeight := sHeight * PixelPerBit;
  MemBuffer := TBitmap.Create;
  MemBuffer.SetSize(ClientWidth, ClientHeight);
  Brush.Style := bsClear;
  Clear;
  Draw;
  StartGame;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  MemBuffer.Free;
  if Gaming then
    FinishGame;
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  //keys for player 1
  case Key of
    Word('W'): if RealFacing <> sfDown then
        Game.Facing := sfUp;
    Word('S'): if RealFacing <> sfUp then
        Game.Facing := sfDown;
    Word('A'): if RealFacing <> sfRight then
        Game.Facing := sfLeft;
    Word('D'): if RealFacing <> sfLeft then
        Game.Facing := sfRight;
  end;

  //Keys for player 2 - when it's choose to play with two players
  case Key of
    VK_UP: if RealFacing <> sfDown then
        Game.Facing := sfUp;
    VK_DOWN: if RealFacing <> sfUp then
        Game.Facing := sfDown;
    VK_LEFT: if RealFacing <> sfRight then
        Game.Facing := sfLeft;
    VK_RIGHT: if RealFacing <> sfLeft then
        Game.Facing := sfRight;
  end;
end;

procedure TMainForm.FormPaint(Sender: TObject);
begin
  Draw;
end;

procedure TMainForm.GameError(const Msg: string);
begin
  raise Exception.Create(Msg);
end;

procedure TMainForm.GameOver;
begin
  FinishGame;
  case messagedlg('Game Over! Want to play a new game?', mtWarning,[mbYes,mbNo], 0) of
    mrYes: StartGame;
    mrNo: Close;
  end;
end;

procedure TMainForm.StartGame;
begin
  Game := TGame.Create(sWidth, sHeight);
  Game.OnGameOver := GameOver;
  RealFacing := Game.Facing;
  Gaming := True;
  tmrStep.Enabled := True;
end;

procedure TMainForm.tmrStepTimer(Sender: TObject);
begin
  Game.Step;
  RealFacing := Game.Facing;
  Game.Display(ScreenBuffer);
  Draw;
end;

end.

