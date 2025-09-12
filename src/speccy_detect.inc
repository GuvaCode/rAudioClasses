   // Проверка на PT3 (ProTracker 3.x: "ProTracker 3.")
    if (Header[0] = $50) and (Header[1] = $72) and  // 'Pr'
       (Header[2] = $6F) and (Header[3] = $54) and  // 'oT'
       (Header[4] = $72) and (Header[5] = $61) and  // 'ra'
       (Header[6] = $63) and (Header[7] = $6B) and  // 'ck'
       (Header[8] = $65) and (Header[9] = $72) and  // 'er'
       (Header[10] = $20) and (Header[11] = $33) and // ' 3'
       (Header[12] = $2E) then                      // '.'
      Exit(ptZxTune);

    // Проверка на Vortex Tracker I ("Vortex Tracker I")
    if (Header[0] = $56) and (Header[1] = $6F) and  // 'Vo'
       (Header[2] = $72) and (Header[3] = $74) and  // 'rt'
       (Header[4] = $65) and (Header[5] = $78) and  // 'ex'
       (Header[6] = $20) and (Header[7] = $54) and  // ' T'
       (Header[8] = $72) and (Header[9] = $61) and  // 'ra'
       (Header[10] = $63) and (Header[11] = $6B) and // 'ck'
       (Header[12] = $65) and (Header[13] = $72) and // 'er'
       (Header[14] = $20) and (Header[15] = $49) then // ' I'
      Exit(ptZxTune);

    // Vtx
    if (Header[0] = $61) and (Header[1] = $79) then Exit(ptZxTune);

    // Spectrum Pro Sound Creator chiptune PSC
    if (Header[0] = $50) and (Header[1] = $53) and
       (Header[2] = $43) and (Header[3] = $20) and
       (Header[4] = $56) then Exit(ptZxTune);

    //PSG chiptune
    if (Header[0] = $50) and (Header[1] = $53) and
       (Header[2] = $47) and (Header[3] = $1A) then Exit(ptZxTune);

    //PSG chiptune(alt)
    if (Header[0] = $50) and (Header[1] = $53) and
       (Header[2] = $47) and (Header[3] = $23) then Exit(ptZxTune);

    // У которых нет сигнатур определяем по расширению

    if (tmpExt = '.pt1') or (tmpExt = '.pt2') or (tmpExt = '.asc') // or (tmpExt = '.st1')
    or (tmpExt = '.stp') then Exit(ptZxTune);

   // Определяем для ptZxTune
   // Chip Tracker module .chi
   // https://zxart.ee/rus/muzyka/poisk-po-baze/rating:4/format:CHI/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
   if (Header[0] = $50) and (Header[1] = $53) and
      (Header[2] = $47) and (Header[3] = $23)  then Exit(ptZxTune);

    //E-Tracker chiptune .etc
    // https://zxart.ee/rus/muzyka/poisk-po-baze/rating:4/format:COP/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
    if (Header[10] = $45) and (Header[11] = $54) and
       (Header[12] = $72) and (Header[13] = $61) and
       (Header[14] = $63) and (Header[15] = $6B) and
       (Header[16] = $65) and (Header[17] = $72) then Exit(ptZxTune);   // cop?

    // Spectrum Fast Tracker chiptune .ftc
    // https://zxart.ee/rus/muzyka/poisk-po-baze/rating:4/format:FTC/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
    if (Header[0] = $4D) and (Header[1] = $6F) and
       (Header[2] = $64) and (Header[3] = $75) and
       (Header[4] = $6C) and (Header[5] = $65) and
       (Header[6] = $3A) and (Header[7] = $20) then Exit(ptZxTune);

    // Spectrum Global Tracker chiptune .gtr
    // https://zxart.ee/rus/muzyka/poisk-po-baze/rating:4/format:GTR/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
    if (Header[1] = $47) and (Header[2] = $54) and
       (Header[3] = $52) and (Header[4] = $10) then Exit(ptZxTune);

    if (tmpExt = '.dmm') //
    or (tmpExt = '.dst')
    or (tmpExt = '.m')
    or (tmpExt = '.s')
    or (tmpExt = '.st1')
    or (tmpExt = '.stc')
    or (tmpExt = '.stp')
    or (tmpExt = '.str') // header?
    or (tmpExt = '.tfe')
    or (tmpExt = '.tfc')
    or (tmpExt = '.mtc')
    or (tmpExt = '.psm')  or (tmpExt = '.st3')  then Exit(ptZxTune);

    if (tmpExt = '.tfc') or (tmpExt = '.pt2') or (tmpExt = '.asc') or (tmpExt = '.stc')
    or (tmpExt = '.stp') or (tmpExt = '.chp') then Exit(ptZxTune);


   // pdt https://zxart.ee/rus/muzyka/poisk-po-baze/rating:1/format:PDT/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
   // SQD https://zxart.ee/rus/muzyka/poisk-po-baze/rating:4/format:SQD/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
   // st3 https://zxart.ee/rus/muzyka/poisk-po-baze/rating:1/format:ST3/sortParameter:votes/sortOrder:rand/resultsType:zxitem/
