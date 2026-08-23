object MainForm: TMainForm
  Left = 0
  Top = 0
  BorderStyle = bsSingle
  Caption = 'Cobra-Kai'
  ClientHeight = 484
  ClientWidth = 506
  Color = clMoneyGreen
  DoubleBuffered = True
  Font.Charset = ANSI_CHARSET
  Font.Color = clWhite
  Font.Height = -16
  Font.Name = 'TeXGyreCursor'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnPaint = FormPaint
  TextHeight = 18
  object tmrStep: TTimer
    Enabled = False
    Interval = 200
    OnTimer = tmrStepTimer
    Left = 462
    Top = 16
  end
end
