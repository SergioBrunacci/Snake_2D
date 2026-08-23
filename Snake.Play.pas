unit Snake.Play;

interface

uses
  Types, Generics.Collections, Snake.Types;

type
  TGame = class;
  TPixelState = (psEmpty, psHead, psBody, psFood);
  TSnakeFacing = (sfUp, sfDown, sfLeft, sfRight);
  TOnGameOver = procedure of object;

  TGame = class
  private
    FWidth, FHeight: Integer;
    Map: array of array of TPixelState;
    Head: TPoint;
    Body: TQueue<TPoint>;
    FOnGameOver: TOnGameOver;
    procedure SetOnGameOver(const Value: TOnGameOver);
    procedure NewFood;
    function Next: TPoint; inline;
  public
    Facing: TSnakeFacing;
    constructor Create(const AWidth, AHeight: Integer);
    destructor Destroy; override;
    procedure Step;
    procedure Display(var Screen: TScreenBuffer);
    property OnGameOver: TOnGameOver read FOnGameOver write SetOnGameOver;
  end;

implementation

constructor TGame.Create(const AWidth, AHeight: Integer);
var
  i, j: Integer;
begin
  FWidth := AWidth;
  FHeight := AHeight;
  SetLength(Map, FWidth, FHeight);
  for i := 0 to High(Map) do
    for j := 0 to High(Map[0]) do
      Map[i, j] := psEmpty;
  Randomize;
  i := Random(FWidth div 2) + FWidth div 4;
  j := Random(FHeight div 2) + FHeight div 4;
  Facing := TSnakeFacing(Random(4));
  Head := Point(i, j);
  Body := TQueue<TPoint>.Create;
  Map[Head.X, Head.Y] := psBody;
  Body.Enqueue(Head);
  Head := Next;
  Map[Head.X, Head.Y] := psBody;
  Body.Enqueue(Head);
  Head := Next;
  Map[Head.X, Head.Y] := psHead;
  NewFood;
end;

destructor TGame.Destroy;
begin
  Body.Free;
end;

procedure TGame.Display(var Screen: TScreenBuffer);
var
  i, j: Integer;
begin
  for i := 0 to High(Map) do
    for j := 0 to High(Map[0]) do
      case Map[i, j] of
        psEmpty:
          Screen[i, j] := bcWhite;
        psFood:
          Screen[i, j] := bcRed;
        psBody:
          Screen[i, j] := bcGreen;
        psHead:
          Screen[i, j] := bcBlack;
      end;
end;

procedure TGame.NewFood;
var
  i, j: Integer;
begin
  repeat
    i := Random(FWidth);
    j := Random(FHeight);
  until Map[i, j] = psEmpty;
  Map[i, j] := psFood;
end;

function TGame.Next: TPoint;
begin
  case Facing of
    sfUp:    Result := Point(Head.X, Head.Y - 1);
    sfDown:  Result := Point(Head.X, Head.Y + 1);
    sfLeft:  Result := Point(Head.X - 1, Head.Y);
    sfRight: Result := Point(Head.X + 1, Head.Y);
  end;
  if Result.X >= FWidth then Dec(Result.X, FWidth);
  if Result.X < 0 then Inc(Result.X, FWidth);
  if Result.Y >= FHeight then Dec(Result.Y, FHeight);
  if Result.Y < 0 then Inc(Result.Y, FWidth);
end;

procedure TGame.SetOnGameOver(const Value: TOnGameOver);
begin
  FOnGameOver := Value;
end;

procedure TGame.Step;
var
  Next: TPoint;
  Tail: TPoint;
begin
  Next := Self.Next;
  case Map[Next.X, Next.Y] of
    psEmpty:
    begin
      Map[Head.X, Head.Y] := psBody;
      Body.Enqueue(Head);
      Head := Next;
      Map[Head.X, Head.Y] := psHead;
      Tail := Body.Dequeue;
      Map[Tail.X, Tail.Y] := psEmpty;
    end;
    psFood:
    begin
      Map[Head.X, Head.Y] := psBody;
      Body.Enqueue(Head);
      Head := Next;
      Map[Head.X, Head.Y] := psHead;
      NewFood;
    end;
    psBody: OnGameOver;
  end;
end;

end.

