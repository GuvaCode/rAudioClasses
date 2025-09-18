unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, rAudioPlayer, rAudioIntf, Types, math;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    Button2: TButton;
    Button3: TButton;
    Button4: TButton;
    Button5: TButton;
    Button6: TButton;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    PaintBox1: TPaintBox;
    ProgressBar1: TProgressBar;
    ProgressBar2: TProgressBar;
    ProgressBar3: TProgressBar;
    ProgressBar4: TProgressBar;
    Timer1: TTimer;
    Timer2: TTimer;
    ToggleBox1: TToggleBox;
    TrackBar1: TTrackBar;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure Button6Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure PaintBox1Paint(Sender: TObject);
    procedure ProgressBar1ContextPopup(Sender: TObject; MousePos: TPoint;
      var Handled: Boolean);
    procedure Timer1Timer(Sender: TObject);
    procedure Timer2Timer(Sender: TObject);
    procedure TrackBar1Change(Sender: TObject);
  private

  public
    Player: TrAudioPlayer;
    procedure DoPlayEvent(Sender: TObject; Track: Integer);
    procedure DoPauseEvent(Sender: TObject; Track: Integer);
    procedure DoStopEvent(Sender: TObject; Track: Integer);
    procedure DoEndEvent(Sender: TObject; Track: Integer; FinishedNormally: Boolean);
    procedure DoErrorEvent(Sender: TObject; const Msg: string);

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
var i: integer;
begin

  Memo1.Clear;
  Player := TrAudioPlayer.Create;
  Player.OnPlay := @DoPlayEvent;
  Player.OnPause := @DoPauseEvent;
  Player.OnStop := @DoStopEvent;
  Player.OnEnd := @DoEndEvent;
  Player.OnError:= @DoErrorEvent;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
 Player.Stop;
end;

procedure TForm1.PaintBox1Paint(Sender: TObject);
var
  Bands: TEqBandsDecay;
  i, BandWidth, BandHeight: Integer;
  BandValue: Single;
  Colors: array[0..5] of TColor = (clRed, clYellow, clLime, clAqua, clBlue, clFuchsia);
  BandNames: array[0..5] of string = ('Bass', 'Low', 'Mid', 'High', 'VHigh', 'Top');
begin
  if not Assigned(Player) then Exit;

  Bands := Player.GetEQBandsDecay;
  if Length(Bands) = 0 then Exit;

  with PaintBox1.Canvas do
  begin
    // Градиентный фон
    Brush.Color := clBlack;
    FillRect(0, 0, PaintBox1.Width, PaintBox1.Height);

    // Рисуем сетку
    Pen.Color := clGray;
    Pen.Style := psDot;
    for i := 1 to 3 do
    begin
      MoveTo(0, PaintBox1.Height * i div 4);
      LineTo(PaintBox1.Width, PaintBox1.Height * i div 4);
    end;

    // Рисуем 6 бэндов
    BandWidth := PaintBox1.Width div 6;
    Pen.Style := psSolid;

    for i := 0 to Min(5, High(Bands)) do
    begin
      BandValue := Bands[i];
      BandHeight := Round(BandValue * PaintBox1.Height * 0.9);

      // Градиентная заливка
    //  Brush.Color := Colors[i];
    //  Pen.Color := Colors[i];

      // Рисуем столбец
      RoundRect(
        i * BandWidth + 3,
        PaintBox1.Height - BandHeight,
        (i + 1) * BandWidth - 3,
        PaintBox1.Height,
        5, 5
      );

      // Подпись бэнда
      Font.Color := clWhite;
      Font.Size := 7;
      Font.Style := [fsBold];
      TextOut(
        i * BandWidth + BandWidth div 2 - TextWidth(BandNames[i]) div 2,
        PaintBox1.Height - 12,
        BandNames[i]
      );

      // Значение
      Font.Size := 6;
      TextOut(
        i * BandWidth + BandWidth div 2 - TextWidth(Format('%.1f', [BandValue])) div 2,
        PaintBox1.Height - BandHeight - 15,
        Format('%.1f', [BandValue])
      );
    end;
  end;
end;

procedure TForm1.ProgressBar1ContextPopup(Sender: TObject; MousePos: TPoint;
  var Handled: Boolean);
begin

end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  i: Integer;
  Bands: TEqBandsDecay;
begin
  if Assigned(Player) then
  begin
    // Обновляем позицию воспроизведения
    ProgressBar1.Position := Player.GetPosition;
 //   TrackBar1.Position := Player.GetPosition;

    // Получаем данные эквалайзера
   // Bands := Player.GetEQBandsDecay;



    // Для отладки: выводим все полосы в Memo
   { Memo1.Lines.BeginUpdate;
    try
      if Memo1.Lines.Count > 20 then
        Memo1.Lines.Clear;

      Memo1.Lines.Add('EQ Bands:');
      for i := 0 to High(Bands) do
        Memo1.Lines.Add(Format('Band %d: %.3f', [i, Bands[i]]));
    finally
      Memo1.Lines.EndUpdate;
    end;}
  end;
end;

procedure TForm1.Timer2Timer(Sender: TObject);
var Bands: TEqBandsDecay;
begin

  // Получаем данные эквалайзера
 // Bands := Player.GetEQBandsDecay;
  // Обновляем ProgressBar2 (можно выбрать любую полосу)
 { if Length(Bands) > 0 then
    ProgressBar2.Position := Round(Bands[0] * ProgressBar2.Max);

  if Length(Bands) > 0 then
    ProgressBar3.Position := Round(Bands[2] * ProgressBar3.Max);

  if Length(Bands) > 0 then
    ProgressBar4.Position := Round(Bands[4] * ProgressBar4.Max);
       }
  PaintBox1.Invalidate;
end;

procedure TForm1.TrackBar1Change(Sender: TObject);
begin
  Player.SetPosition(TrackBar1.Position);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
if openDialog1.Execute then
begin
 Player.Play(OpenDialog1.FileName,6);
 Player.SetLoopMode(true); // Установить режим перед воспроизведением
 ProgressBar1.Max := Player.GetDuration;
 TrackBar1.Max := Player.GetDuration;
 Memo1.Lines.Add('Current track: ' +  inttostr(Player.GetCurrentTrack));
 Memo1.Lines.Add('Track count: ' +  inttostr(Player.GetTrackCount));
 Memo1.Lines.Add(Player.GetCurrentEngine);
end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
    Player.SetLoopMode(not Player.GetLoopMode); // Переключаем режим
  if Player.GetLoopMode then
    Memo1.Lines.Add('Loop mode: ON')
  else
    Memo1.Lines.Add('Loop mode: OFF');
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  Player.Stop;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
  Player.SetPosition(Player.GetPosition + 1);
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
  if not Player.IsPaused then Player.Pause else
    Player.Resume;
end;

procedure TForm1.Button6Click(Sender: TObject);
begin
 // Player.Play();
end;

procedure TForm1.DoPlayEvent(Sender: TObject; Track: Integer);
begin
 Memo1.Lines.Add('Do PLay');
end;

procedure TForm1.DoPauseEvent(Sender: TObject; Track: Integer);
begin
 Memo1.Lines.Add('Do pause');
end;

procedure TForm1.DoStopEvent(Sender: TObject; Track: Integer);
begin
 Memo1.Lines.Add('Do stop');
end;

procedure TForm1.DoEndEvent(Sender: TObject; Track: Integer;
  FinishedNormally: Boolean);
begin
 Memo1.Lines.Add('Do end');
end;

procedure TForm1.DoErrorEvent(Sender: TObject; const Msg: string);
begin
 Memo1.Lines.Add(Msg);
end;

end.

