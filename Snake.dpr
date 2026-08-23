program Snake;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  Snake.Types in 'Snake.Types.pas',
  Snake.Play in 'Snake.Play.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.

