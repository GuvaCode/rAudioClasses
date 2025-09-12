unit spectrum_vis;
{ Spectrum Visualyzation by Alessandro Cappellozza
  version 0.8 05/2002
  http://digilander.iol.it/Kappe/audioobject

  Modified for proper horizontal display
}
interface
  uses Dialogs, Graphics, SysUtils, CommonTypes, Classes, LCLType, LCLIntf;

 type TSpectrum = Class(TObject)
    private
      VisBuff : TBitmap;
      BackBmp : TBitmap;
      BkgColor : TColor;
      SpecHeight : Integer;
      PenColor : TColor;
      PeakColor: TColor;
      DrawType : Integer;
      DrawRes  : Integer;
      FrmClear : Boolean;
      UseBkg   : Boolean;
      PeakFall : Integer;
      LineFall : Integer;
      ColWidth : Integer;
      ShowPeak : Boolean;
      FFTPeacks  : array [0..127] of Integer;  // 128 полос
      FFTFallOff : array [0..127] of Integer;  // 128 полос
    public
     Constructor Create (Width, Height : Integer);
     procedure Draw(Canvas: TCanvas; FFTData : TFFTData; X, Y : Integer);
     procedure SetBackGround (Active : Boolean; BkgCanvas : TGraphic);
     property BackColor : TColor read BkgColor write BkgColor;
     property Height : Integer read SpecHeight write SpecHeight;
     property Pen  : TColor read PenColor write PenColor;
     property Peak : TColor read PeakColor write PeakColor;
     property Mode : Integer read DrawType write DrawType;
     property Res  : Integer read DrawRes write DrawRes;
     property FrameClear : Boolean read FrmClear write FrmClear;
     property PeakFallOff: Integer read PeakFall write PeakFall;
     property LineFallOff: Integer read LineFall write LineFall;
     property DrawPeak   : Boolean read ShowPeak write ShowPeak;
  end;

 var Spectrum : TSpectrum;

implementation

Constructor TSpectrum.Create(Width, Height : Integer);
begin
  VisBuff := TBitmap.Create;
  BackBmp := TBitmap.Create;
  VisBuff.Width := Width;
  VisBuff.Height := Height;
  BackBmp.Width := Width;
  BackBmp.Height := Height;
  BkgColor := clBlack;
  SpecHeight := Height;
  PenColor := clLime;
  PeakColor := clYellow;
  DrawType := 1;  // Столбцы
  DrawRes  := 1;
  FrmClear := True;
  UseBkg := False;
  PeakFall := 2;
  LineFall := 5;
  ColWidth := 3;
  ShowPeak := True;

  // Инициализируем массивы
  FillChar(FFTPeacks, SizeOf(FFTPeacks), 0);
  FillChar(FFTFallOff, SizeOf(FFTFallOff), 0);
end;

procedure TSpectrum.SetBackGround (Active : Boolean; BkgCanvas : TGraphic);
begin
  UseBkg := Active;
  BackBmp.Canvas.Draw(0, 0, BkgCanvas);
end;

procedure TSpectrum.Draw(Canvas: TCanvas; FFTData : TFFTData; X, Y : Integer);
var
  i, YPos: Integer;
  YVal: Single;
  BandWidth: Integer;
  ActualBands: Integer;
begin
  // Определяем количество отображаемых полос (максимум 64 для лучшего вида)
  ActualBands := 64;
  BandWidth := (VisBuff.Width - 1) div ActualBands;

  if FrmClear then
  begin
    VisBuff.Canvas.Pen.Color := BkgColor;
    VisBuff.Canvas.Brush.Color := BkgColor;
    VisBuff.Canvas.Rectangle(0, 0, VisBuff.Width, VisBuff.Height);

    if UseBkg then
      VisBuff.Canvas.CopyRect(Rect(0, 0, BackBmp.Width, BackBmp.Height),
                             BackBmp.Canvas,
                             Rect(0, 0, BackBmp.Width, BackBmp.Height));
  end;

  VisBuff.Canvas.Pen.Color := PenColor;
  VisBuff.Canvas.Brush.Color := PenColor;

  // Рисуем спектр горизонтально
  for i := 0 to ActualBands - 1 do
  begin
    // Берем значение из FFTData (группируем полосы если нужно)
    if (i * 2) < 128 then
      YVal := Abs(FFTData[i * 2])
    else
      YVal := 0;

    // Преобразуем в высоту столбца
    YPos := Trunc(YVal * SpecHeight);
    if YPos > SpecHeight then
      YPos := SpecHeight;

    // Обновляем пиковые значения
    if YPos >= FFTPeacks[i] then
      FFTPeacks[i] := YPos
    else
      FFTPeacks[i] := FFTPeacks[i] - PeakFall;

    if YPos >= FFTFallOff[i] then
      FFTFallOff[i] := YPos
    else
      FFTFallOff[i] := FFTFallOff[i] - LineFall;

    // Ограничиваем значения
    if FFTPeacks[i] < 0 then FFTPeacks[i] := 0;
    if FFTFallOff[i] < 0 then FFTFallOff[i] := 0;
    if FFTPeacks[i] > SpecHeight then FFTPeacks[i] := SpecHeight;
    if FFTFallOff[i] > SpecHeight then FFTFallOff[i] := SpecHeight;

    case DrawType of
      0: // Линии
        begin
          VisBuff.Canvas.MoveTo(X + i, Y + SpecHeight);
          VisBuff.Canvas.LineTo(X + i, Y + SpecHeight - FFTFallOff[i]);

          if ShowPeak then
          begin
            VisBuff.Canvas.Pixels[X + i, Y + SpecHeight - FFTPeacks[i]] := PeakColor;
          end;
        end;

      1: // Столбцы
        begin
          // Рисуем основной столбец
          VisBuff.Canvas.Rectangle(
            X + i * (BandWidth + 1),
            Y + SpecHeight - FFTFallOff[i],
            X + i * (BandWidth + 1) + BandWidth,
            Y + SpecHeight
          );

          // Рисуем пиковый индикатор
          if ShowPeak and (FFTPeacks[i] > 0) then
          begin
            VisBuff.Canvas.Pen.Color := PeakColor;
            VisBuff.Canvas.MoveTo(
              X + i * (BandWidth + 1),
              Y + SpecHeight - FFTPeacks[i]
            );
            VisBuff.Canvas.LineTo(
              X + i * (BandWidth + 1) + BandWidth,
              Y + SpecHeight - FFTPeacks[i]
            );
            VisBuff.Canvas.Pen.Color := PenColor;
          end;
        end;
    end;
  end;

  // Копируем на целевой канвас
  Canvas.CopyRect(
    Rect(X, Y, X + VisBuff.Width, Y + VisBuff.Height),
    VisBuff.Canvas,
    Rect(0, 0, VisBuff.Width, VisBuff.Height)
  );
end;

end.
