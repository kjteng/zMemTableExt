unit ZMemTableExt;
{$DEFINE USE_MY_STREAMIMG_METHOD}

{$mode objfpc}{$H+}
{$modeswitch typehelpers}
interface

uses  ZMemTable, ZStream, db,  ZDataset, Classes, SysUtils;

Type
  TByteSet = set of Byte;

  TZMemTableHelper = class helper for TZMemTable
      private
      public
        procedure LoadFromBlob(BField: TBlobField);
        procedure SaveToBlob(BField: TBlobField);
        procedure LoadFromFile(Filename: TFilename);
        procedure SaveToFile(Filename: TFilename; zip: Boolean =True);
        procedure SetDecPlace(ftype: TFieldType; dec: byte);
        procedure CopyStru(src: TDataSet; xcFields: TByteSet =[];
                                                 DeleteOldfields: Boolean=True);
        procedure CopyData(src: TDataSet);
        {$IFDEF USE_MY_STREAMIMG_METHOD} // these shall be superseded by the new mtd in zMemTable.pas
        procedure LoadFromStream(AStream: TStream);
        procedure SaveToStream(AStream: TStream);
        {$ENDIF}
    end;


procedure zzStream(ms: TMemoryStream);
procedure uzStream(ms: TMemoryStream);

implementation

procedure zzStream(ms: TMemoryStream);
var ss: TMemoryStream; zz: Tcompressionstream;  bb: Byte;
begin
  ss := TMemoryStream.Create;
  zz:= TCompressionstream.Create(zstream.clDefault, ss);
  ms.Position := 0;
  while ms.Read(bb, 1) > 0 do
    zz.Write(bb, 1);
  zz.Free;
  ms.Clear;
  ss.SaveToStream(ms);
end;


procedure uzStream(ms: TMemoryStream);
var uz: Tdecompressionstream;
    ss: TMemoryStream;
    bb: Byte;
begin
  ms.Position := 0;
  uz := Tdecompressionstream.Create(ms);
  ss := TMemoryStream.Create;
  uz.Position := 0;

  while uz.Read(bb, 1) > 0 do
      ss.Write(bb, 1);
  uz.Free;
  ms.Clear;
  ms.Position := 0;
  ss.SaveToStream(ms);
  ss.Free;
end;


procedure TZMemTableHelper.LoadFromBlob(BField: TBlobField);
var ms, ss: TMemoryStream; //ss: TStream;
begin
  Clear;
  ss := TMemoryStream(BField.DataSet.CreateBlobStream(BField, bmRead));
  ms := TMemoryStream.Create;
  ss.SaveToStream(ms); // cannot use ss to uz bcos uzstream will change the stream data in original BLOB field
  try
//    if Zip then
    uzStream(ms);
    ms.Position := 0;
    LoadFromStream(ms);
  finally
    ss.Free;
    ms.Free
  end;
end;


procedure TZMemTableHelper.SaveToBlob(BField: TBlobField);
var ms: TMemoryStream;
begin
  ms := TMemoryStream(BField.DataSet.CreateBlobStream(BField, bmReadWrite));
  try
    SaveToStream(ms);
//    if Zip then
    zzStream(ms);
    ms.Position := 0;
  finally
    ms.Free
  end;
end;


procedure TZMemTableHelper.LoadFromFile(Filename: TFilename);
var ms: TMemoryStream; fs: TFileStream; ii: integer; zip: boolean;
begin
  Clear;
  fs := TFileStream.Create(Filename, fmOpenRead + fmShareCompat);
  fs.Read(ii, Sizeof(ii));
  zip := ii = 0;
  ms := TMemoryStream.Create;
  ii := fs.Size;
  if zip then  //read from current position
    dec(ii, sizeOf(ii))
  else
    fs.Position:= 0;
  ms.SetSize(ii);
  fs.ReadBuffer(ms.Memory^, ii);
  try
    if zip then
      uzStream(ms);
    ms.Position:= 0;
    LoadFromStream(ms) ;
  finally;
    ms.Free;
    fs.Free;
  end;
end;


procedure TZMemTableHelper.SaveToFile(Filename: TFilename; zip: Boolean =True);
var ms: TMemoryStream; fs: TFileStream; ii: Integer;
begin
  fs := TFileStream.Create(Filename, fmCreate);
  ms := TMemoryStream.Create;
  try
    ms.Position := 0;
    SaveToStream(ms);
    if zip then
      begin
        zzStream(ms);
        ii := 0;
        fs.Write(ii, sizeof(ii));
      end;
    ms.Position := 0;
    fs.WriteBuffer(ms.memory^, ms.Size);
  finally
    ms.Free;
    fs.Free;
  end;
end;

procedure TZMemTableHelper.CopyStru(src: TDataSet; xcFields: TByteSet =[];
                                              DeleteOldFields: Boolean=True);
var ii: Integer;
begin
  Close;
  if DeleteOldFields then
    FieldDefs.Clear;
  for ii := 0 to src.Fieldcount-1 do
    if not (ii in xcFields) then
      try
        with src.Fields[ii] do
          FieldDefs.Add(FieldName, DataType, Size, Required);
      except
      end;
  Open;
end;


procedure TZMemTableHelper.CopyData(src: TDataSet);
var ii, kk: Integer; map: array of TPoint; fd: TField;
begin
  SetLength(map, FieldCount);
  kk := 0;
  for ii := 0 to FieldCount -1 do
    begin // Pairing fields with same fieldname
      fd := src.FindField(Fields[ii].FieldName);
      if  fd <> nil then
        begin
          map[kk] := Point(ii, fd.Index);
          inc(kk)
        end; // OR system.Insert(Point(ii, fd.Index), map, Length(map) );
    end;
  SetLength(map, kk);  // remove unused item
  Close; Open; //clear data
  src.First;
  while not src.EOF do
    begin
      Append;
      for ii := 0 to high(map) do
          Fields[map[ii].x].Value := src.Fields[map[ii].y].Value;
      Post;
      src.Next
    end;
end;


procedure TZMemTableHelper.SetDecPlace(ftype: TFieldType; dec: byte);
var ii: integer;
begin
  for ii := 0 to FieldCount-1 do
    if Fields[ii].DataType = Ftype then
      TNumericField(Fields[ii]).DisplayFormat:= '#,##0.' + StringofChar('0', dec);
end;


{$IFDEF USE_MY_STREAMIMG_METHOD}

//{$DEFINE STORE_PRECISION_FOR_FLOATFIELD}
procedure TZMemTableHelper.LoadFromStream(AStream: TStream);
var
  len, a, b, cc, kk: Integer;  tx: string;  req: Boolean;
  tb: TBytes;   fType: TFieldType;
  ar: array of TPoint; // x= FieldNo of float field y = precision

  function ReadByte: Byte;
  begin
    result := 0;
    AStream.Read(result, 1)
  end;

  function ReadInt: longint;
  begin
    result := 0;
    AStream.Read(result, Sizeof(longint));
  end;

  function ReadStr: string;
  begin
    result := '';
    cc := ReadInt;
    SetLength(result, cc);
    AStream.Readbuffer(Pointer(result)^, cc);
  end;

  procedure ReadBlob;
  var ms: TMemoryStream;
  begin
    cc := ReadInt;
    if cc > 0 then
      begin
        ms := TMemoryStream.Create;
        try
          ms.CopyFrom(AStream, cc);
         (Fields[b] as TBlobField).LoadFromStream(ms);
        finally
          ms.Free;
        end;
      end;
  end;

  procedure ReadData;
  begin
    cc := ReadInt;
    SetLength(tb, cc);
    AStream.ReadBuffer(Pointer(tb)^, cc);
    Fields[b].SetData(Pointer(tb));
  end;

begin
    CheckInactive;
   // Close;
    Self.Clear;
   // Self.FieldDefs.Clear;
    DisableControls;
    AStream.Position:= 0;
    kk := ReadInt; //fieldcount
    SetLength(ar, kk);
    try
      for a := 0 To kk-1 do
        begin
          tx := ReadStr;
       //   ftype := ReadInt;
          ftype :=  TFieldType(ReadInt);
          len := ReadInt;
          req := ReadByte > 0;
          FieldDefs.Add(tx, fType, len, req);
        end;
      Open;  // Open - setup fields structure for memtable
      for kk := 0 to high(ar) do
        case fields[kk].DataType of
          ftFloat, ftBCD: TNumericField(fields[kk]).DisplayFormat:= '#,###.00';
          ftCurrency:  TNumericField(fields[kk]).DisplayFormat:= '#,###.0000';
        end;
      kk := ReadInt; // recordcount
      for a := 1 to kk do
        begin
          Append;
          for b := 0 to FieldCount - 1 do
            begin
              case Fields[b].DataType of
                ftString, ftMemo: Fields[b].AsString :=  ReadStr;
                ftBlob: try ReadBlob; except end;
                else  ReadData;
              end; //case
            end;
            Post;
        end;
      {try
        while true do
          begin
            Append;
            for b := 0 to FieldCount - 1 do
              begin
                cc := ReadInt;
                case cc of
                  -maxint..-1: ReadBlob;
                  0:           ; //No data - ignore
                  1..1000:     ReadData; //simple type
                  1001:        Fields[b].AsString :=  ReadStr;
                end; //case
              end;
            if AStream.Position < AStream.Size then
              Post
            else
              begin
                Cancel ;
                Break
              end;
          end;
      except
      end; }
      First;
    finally
      EnableControls;
    end;
end;


procedure TZMemTableHelper.SaveToStream(AStream: TStream);
var bm: TBookMark; a, cc: Integer;
    tb: TBytes;

  procedure WriteByte(bb: byte);
  begin
    AStream.Write(bb, 1);
  end;

  procedure WriteInt(ii: longint);
  begin
    AStream.Write(ii, Sizeof(longint))
  end;

  procedure WriteStr(tx: string);
  begin
    cc := Length(tx); WriteInt(cc);
    AStream.WriteBuffer(Pointer(tx)^, cc);
  end;

  procedure WriteBlob;
  var ms: TMemoryStream;
  begin
    ms:= TMemoryStream.Create;
    try
      (Fields[a] as TBlobField).SaveToStream(ms);
      cc := ms.Size;
      WriteInt(cc);
      if cc > 0 then
        begin
          ms.Position := 0;
          AStream.CopyFrom(ms, cc);
        end;
    finally
      ms.Free;
    end;
  end;

  procedure WriteData;
  begin
    cc := Fields[a].DataSize;
    SetLength(tb, cc);
    Fields[a].GetData(Pointer(tb));
    WriteInt(cc);
    AStream.Writebuffer(Pointer(tb)^, cc);
  end;

begin
  CheckActive;
  bm := GetBookmark;
  AStream.Position:= 0;
  try
    DisableControls;

    try
      WriteInt(FieldDefs.Count);
      for a := 0 To FieldDefs.Count - 1 do
        begin
          WriteStr(FieldDefs[a].Name);
          WriteInt(ord(FieldDefs[a].DataType));
          WriteInt(FieldDefs[a].Size);
          WriteByte(Byte(FieldDefs[a].Required));
        end;
      WriteInt(RecordCount);
      First;
      while not Eof Do
        begin
          for a := 0 To FieldCount - 1 Do
            case Fields[a].DataType of
                ftString, ftMemo: WriteStr(Fields[a].AsString);
                ftBlob: WriteBlob;
                else WriteData
            end; //case
          Next;
        end;
    finally
      EnableControls;
    end;
  finally
    GotoBookmark(bm);
  end;
end;
{$ENDIF}
end.
