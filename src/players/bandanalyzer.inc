var
  i, j, SampleCount: Integer;
  Sample: SmallInt;
  ChannelCount: Integer;
  SampleValue, Energy: Double;
  BandFactors: array[0..5] of Double = (0.1, 0.3, 0.5, 0.7, 0.9, 1.1);
begin
  if size = 0 then Exit;

  ChannelCount := DEFAULT_CHANNELS;
  SampleCount := size div (DEFAULT_BITS div 8) div ChannelCount;

  if SampleCount = 0 then Exit;

  // Анализируем каждый 10-й семпл для производительности
  for i := 0 to SampleCount - 1 do
  begin
    if i mod 10 <> 0 then Continue;

    Sample := PSmallInt(buffer + i * ChannelCount * (DEFAULT_BITS div 8))^;
    SampleValue := Abs(Sample) / 32768.0;

    // Распределяем энергию по бэндам с разными коэффициентами
    for j := 0 to High(FEqBands) do
    begin
      Energy := SampleValue * BandFactors[j] * (1.2 - j * 0.15);
      FEqBands[j] := FEqBands[j] + Energy * Energy;
    end;
  end;

  // Обрабатываем бэнды
  for j := 0 to High(FEqBands) do
  begin
    FEqBands[j] := Sqrt(FEqBands[j] / (SampleCount / 10));
    FEqBands[j] := Log10(FEqBands[j] * 50 + 1) * 0.8;

    if FEqBands[j] > FEqBandsDecay[j] then
      FEqBandsDecay[j] := FEqBands[j]
    else
      FEqBandsDecay[j] := FEqBandsDecay[j] * (0.88 + j * 0.02);

    FEqBandsDecay[j] := Min(1.0, Max(0, FEqBandsDecay[j]));
    FEqBands[j] := 0;
  end;      
