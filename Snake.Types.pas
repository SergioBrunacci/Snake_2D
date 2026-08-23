unit Snake.Types;

interface

uses
  Graphics;

const
  sWidth = 35;
  sHeight = 35;
  PixelPerBit = 17;

type
  TBinaryColor = (bcBlack, bcGreen,  bcRed, bcWhite);

  TScreenBuffer = array[0..sWidth - 1, 0..sHeight - 1] of TBinaryColor;

const
  Colors: array[TBinaryColor] of TColor = (clBlack, clGreen, clRed, clWhite);

implementation

end.

