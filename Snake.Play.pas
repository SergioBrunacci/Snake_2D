unit Snake.Play;

interface

uses
  System.Types, System.SysUtils, System.Generics.Collections, Snake.Types;

type
  // Enumerated state for every cell in the logical grid
  TPixelState = (psEmpty, psHead, psBody, psFood);

  // Direction the snake is travelling; stored per-tick so FRealFacing
  // on the form can guard against 180° reversals.
  TSnakeFacing = (sfUp, sfDown, sfLeft, sfRight);

  // Method-reference callback — fires when the head collides with its body.
  // Uses bare `procedure of object` (not TNotifyEvent) because the game
  // does not pass a sender reference.
  TOnGameOver = procedure of object;

  TGame = class
  private
    // ── Simulation state ──────────────────────────────────────────────────
    FWidth, FHeight: Integer;             // Grid dimensions
    FMap: array of array of TPixelState;  // Logical board (col × row)
    FHead: TPoint;                        // Current head coordinates
    FBody: TQueue<TPoint>;                // Body segments from tail→head
    FFacing: TSnakeFacing;                // Last applied direction
    FOnGameOver: TOnGameOver;             // Death callback (nil → silent)

    procedure NewFood;                      // Place food on first empty cell
    function GetNextPoint: TPoint; inline;  // Compute wrapped destination
    procedure DoGameOver;                   // Safely fire death callback
  public
    constructor Create(const AWidth, AHeight: Integer);
    destructor Destroy; override;

    procedure Step;                                // Advance simulation one tick
    procedure Display(var Screen: TScreenBuffer);  // Map internal → colour buffer

    property Facing: TSnakeFacing read FFacing write FFacing;
    property OnGameOver: TOnGameOver read FOnGameOver write FOnGameOver;
  end;

implementation

{ TGame }

// ── Construction ─────────────────────────────────────────────────────────────

constructor TGame.Create(const AWidth, AHeight: Integer);
var
  X, Y: Integer;
  StartPos: TPoint;
begin
  inherited Create;

  FWidth := AWidth;
  FHeight := AHeight;

  // Allocate 2-D grid and fill with empty tiles
  SetLength(FMap, FWidth, FHeight);
  for X := 0 to FWidth - 1 do
    for Y := 0 to FHeight -1 do
      FMap[X, Y] := psEmpty;

  FBody := TQueue<TPoint>.Create;
  Randomize;

  // Seed random initial direction; pick start position near the centre
  FFacing := TSnakeFacing(Random(4));
  X := Random(FWidth div 2) + (FWidth div 4);
  Y := Random(FHeight div 2) + (FHeight div 4);
  StartPos := Point(X, Y);

  FHead := StartPos;
  FMap[FHead.X, FHead.Y] := psHead;  // Mark the starting cell as head
  FBody.Enqueue(FHead);              // Single-segment body queue

  NewFood;                           // Spawn first food target
end;

destructor TGame.Destroy;
begin
  FreeAndNil(FBody);   // Queue owns TPoint structs — must release
  inherited Destroy;
end;

// ── Rendering export ─────────────────────────────────────────────────────────

procedure TGame.Display(var Screen: TScreenBuffer);
var
  X, Y: Integer;
begin
  // Translate internal pixel states → external colour constants
  for X := 0 to FWidth - 1 do
  begin
    for Y := 0 to FHeight - 1 do
    begin
      case FMap[X, Y] of
        psEmpty: Screen[X, Y] := bcWhite;
        psFood: Screen[X, Y] := bcRed;
        psBody: Screen[X, Y] := bcGreen;
        psHead: Screen[X, Y] := bcBlack;
      end;
    end;
  end;
end;

// ── Food management ──────────────────────────────────────────────────────────

procedure TGame.NewFood;
var
  X, Y: Integer;
  EmptyCellsExist: Boolean;
begin
  // Quick scan: abort if the board is completely full (no moves left)
  EmptyCellsExist := False;
  for X := 0 to FWidth -1 do
  begin
    for Y := 0 to FHeight -1 do
    begin
      if FMap[X, Y] = psEmpty then
      begin
        EmptyCellsExist := True;
        Break;
      end;
    end;
    if EmptyCellsExist then Break;
  end;

  if not EmptyCellsExist then  exit;   // Board full — no food to place

  // Pick a random empty cell until one is found
  repeat
    X := Random(FWidth);
    Y := Random(FHeight);
  until FMap[X, Y] = psEmpty;

  FMap[X, Y] := psFood;
end;

// ── Movement logic ───────────────────────────────────────────────────────────

function TGame.GetNextPoint: TPoint;
begin
  // Compute intended next position based on current facing direction
  case FFacing of
    sfUp:    Result := Point(FHead.X, FHead.Y - 1);
    sfDown:  Result := Point(FHead.X, FHead.Y + 1);
    sfLeft:  Result := Point(FHead.X - 1, FHead.Y);
    sfRight: Result := Point(FHead.X + 1, FHead.Y);
  end;

  // ┌───────────────────────────────────────────────────────────────────┐
  // │ Wrap-around arithmetic keeps the snake on a toroidal playfield.   │
  // │ Each bound clamp maps out-of-range coordinates back into [0..N).  │
  // └───────────────────────────────────────────────────────────────────│
  if Result.X >= FWidth then Dec(Result.X, FWidth);
  if Result.X < 0 then Inc(Result.X, FWidth);
  if Result.Y >= FHeight then Dec(Result.Y, FHeight);
  if Result.Y < 0 then Inc(Result.Y, FHeight);         // ⚠ Must be FHeight not FWidth
end;

// ── Death handler ────────────────────────────────────────────────────────────

Procedure TGame.DoGameOver;
begin
  // Fire the main-form callback only if it has been assigned.
  // Assigned() check prevents AV when FOnGameOver is nil (uninitialised delegate).
  if Assigned(FOnGameOver) then
    FOnGameOver;         // Synchronous — executes on caller's stack
end;

// ── Game loop tick ───────────────────────────────────────────────────────────

procedure TGame.Step;
var
  TargetCell: TPoint;
  Tail: TPoint;
  TargetState: TPixelState;
begin
  // Determine where the head wants to move and what occupies that cell
  TargetCell := GetNextPoint;
  TargetState := FMap[TargetCell.X, TargetCell.Y];

  // ┌───────────────────────────────────────────────────────────────────┐
  // │ Self-Tail follow safety check:                                    │
  // │ When the snake is not growing, the tail vacates its cell this     │
  // │ same tick. If the head targets the tail's *current* position, we  │
  // │ treat it as empty rather than body-collision, allowing smooth     │
  // │ pursuit without self-starvation.                                  │
  // │ Note: only applies to psEmpty / psBody — food/wall cells skip     │
  // │ this optimisation (wall hit → game over; food eat → grow).        │
  // └───────────────────────────────────────────────────────────────────│
  if (TargetState = psEmpty) or (TargetState = psBody) then
  begin
    Tail := FBody.Peek;            // Peek avoids dequeuing prematurely
    if (TargetCell.X = Tail.X) and (TargetCell.Y = Tail.Y) then
      TargetState := psEmpty;      // Treat as safe passage
  end;

  // Resolve outcome based on what the head landed on
  case TargetState of

    // ── Move forward (tail follows automatically) ────────────────────
    psEmpty:
    begin
      // Retract old head → body
      FMap[FHead.X, FHead.Y] := psBody;

      // Advance head
      FHead := TargetCell;
      FMap[FHead.X, FHead.Y] := psHead;
      FBody.Enqueue(FHead);

      // Remove oldest body segment (the tail)
      Tail := FBody.Dequeue;
      FMap[Tail.X, Tail.Y] := psEmpty;
    end;

    // ── Eat food (grow — tail stays) ─────────────────────────────────
    psFood:
    begin
      FMap[FHead.X, FHead.Y] := psBody;
      FHead := TargetCell;
      FMap[FHead.X, FHead.Y] := psHead;
      FBody.Enqueue(FHead);

      NewFood;   // Spawn replacement before next tick
    end;

    // ── Hit own body → game over ─────────────────────────────────────
    psBody:
    begin
      DoGameOver;     // Callback fires synchronously
    end;
  end;
end;

end.

