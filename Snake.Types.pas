unit Snake.Types;

interface

uses
  Graphics;

// ── Grid dimensions (fixed at compile time for O(1) array sizing) ────────────
const
  sWidth = 35;        // Logical grid columns (X axis)
  sHeight = 35;       // Logical grid rows    (Y axis)
  PixelPerBit = 17;   // Pixels per logical cell — form window size is
                      //   Width  × 17 by Height × 17 on startup

// ── Colour abstraction — decouples game logic from GDI colour constants ──────
type
  TBinaryColor = (bcBlack, bcGreen,  bcRed, bcWhite);
  //   bcBlack  → snake head
  //   bcGreen  → snake body
  //   bcRed    → food target
  //   bcWhite  → empty floor tile

  // Fixed-size 2-D array mapping every cell coordinate to a colour value.
  // Stored in the main form and updated each tick by TGame.Display().
  TScreenBuffer = array[0..sWidth - 1, 0..sHeight - 1] of TBinaryColor;

// Lookup table: one-to-one bridge between our abstract colours and Windows TColor values.
// Index-by-TBinaryColour gives the matching GDI palette entry — avoids branch statements.
const
  Colors: array[TBinaryColor] of TColor = (clBlack, clGreen, clRed, clWhite);

implementation

end.

